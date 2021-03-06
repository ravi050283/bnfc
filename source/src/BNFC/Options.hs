module BNFC.Options where

import BNFC.CF (CF)
import Data.Maybe (fromMaybe)
import Data.Version ( showVersion )
import Paths_BNFC ( version )
import System.Console.GetOpt
import System.FilePath (takeBaseName)
import Text.Printf (printf)

-- ~~~ Option data structures ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- | To decouple the option parsing from the execution of the program,
-- we introduce a data structure that holds the result of the
-- parsing of the arguments.
data Mode
    -- An error has been made by the user
    -- e.g. invalid argument/combination of arguments
    = UsageError String
    -- Basic modes: print some info and exits
    | Help | Version
    -- Normal mode, specifying the back end to use,
    -- the option record to be passed to the backend
    -- and the path of the input grammar file
    | Target SharedOptions FilePath
  deriving (Eq,Show,Ord)

-- | Target languages
data Target = TargetC | TargetCpp | TargetCppNoStl | TargetCSharp
            | TargetHaskell | TargetHaskellGadt | TargetLatex
            | TargetJava | TargetOCaml | TargetProfile | TargetPygments
  deriving (Eq,Bounded, Enum,Ord)

-- Create a list of all target using the enum and bounded classes
targets :: [Target]
targets = [minBound..]

instance Show Target where
  show TargetC            = "C"
  show TargetCpp          = "C++"
  show TargetCppNoStl     = "C++ (without STL)"
  show TargetCSharp       = "C#"
  show TargetHaskell      = "Haskell"
  show TargetHaskellGadt  = "Haskell (with GADT)"
  show TargetLatex        = "Latex"
  show TargetJava         = "Java"
  show TargetOCaml        = "OCaml"
  show TargetProfile      = "Haskell (with permutation profiles)"
  show TargetPygments     = "Pygments"


-- | Which version of Alex is targeted?
data AlexVersion = Alex1 | Alex2 | Alex3
  deriving (Show,Eq,Ord,Bounded,Enum)

-- | Happy modes
data HappyMode = Standard | GLR
  deriving (Eq,Show,Bounded,Enum,Ord)

data JavaLexerParser = JLexCup | JFlexCup | Antlr4
    deriving (Eq,Show,Ord)

data RecordPositions = RecordPositions | NoRecordPositions
    deriving (Eq,Show,Ord)

-- | This is the option record that is passed to the different backends
data SharedOptions = Options
  -- Option shared by at least 2 backends
  { target :: Target
  , make :: Maybe String     -- ^ The name of the Makefile to generate
  -- or Nothing for no Makefile.
  , inPackage :: Maybe String -- ^ The hierarchical package to put
                              --   the modules in, or Nothing.
  , cnf :: Bool               -- ^ Generate CNF-like tables?
  , lang :: String
  -- Haskell specific:
  , alexMode :: AlexVersion
  , javaLexerParser :: JavaLexerParser
  , inDir :: Bool
  , shareStrings :: Bool
  , byteStrings :: Bool
  , glr :: HappyMode
  , xml :: Int
  , ghcExtensions :: Bool
  , agda :: Bool                   -- ^ Create bindings for Agda?
  -- C++ specific
  , linenumbers :: RecordPositions -- ^ Add and set line_number field for syntax classes
  -- C# specific
  , visualStudio :: Bool      -- ^ Generate Visual Studio solution/project files
  , wcf :: Bool               -- ^ Windows Communication Foundation
  , functor :: Bool
  , outDir :: FilePath        -- ^ Target directory for generated files
  } deriving (Eq,Show,Ord)

-- | We take this oportunity to define the type of the backend functions
type Backend = SharedOptions  -- ^ options
            -> CF             -- ^ Grammar
            -> IO ()

defaultOptions :: SharedOptions
defaultOptions = Options
  { cnf = False
  , target = TargetHaskell
  , inPackage = Nothing
  , make = Nothing
  , alexMode = Alex3
  , inDir = False
  , shareStrings = False
  , byteStrings = False
  , glr = Standard
  , xml = 0
  , ghcExtensions = False
  , agda = False
  , lang = error "lang not set"
  , linenumbers = NoRecordPositions
  , visualStudio = False
  , wcf = False
  , functor = False
  , outDir  = "."
  , javaLexerParser = JLexCup
  }

-- ~~~ Option definition ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- This defines bnfc's "global" options, like --help
globalOptions :: [ OptDescr Mode ]
globalOptions = [
  Option [] ["help"]                      (NoArg Help)         "show help",
  Option [] ["version","numeric-version"] (NoArg Version)      "show version number"]

-- | Options for the target languages
-- targetOptions :: [ OptDescr Target ]
targetOptions :: [ OptDescr (SharedOptions -> SharedOptions)]
targetOptions =
  [ Option "" ["java"]          (NoArg (\o -> o {target = TargetJava}))
    "Output Java code [default: for use with JLex and CUP]"
  , Option "" ["haskell"]       (NoArg (\o -> o {target = TargetHaskell}))
    "Output Haskell code for use with Alex and Happy (default)"
  , Option "" ["haskell-gadt"]  (NoArg (\o -> o {target = TargetHaskellGadt}))
    "Output Haskell code which uses GADTs"
  , Option "" ["latex"]         (NoArg (\o -> o {target = TargetLatex}))
    "Output LaTeX code to generate a PDF description of the language"
  , Option "" ["c"]             (NoArg (\o -> o {target = TargetC}))
    "Output C code for use with FLex and Bison"
  , Option "" ["cpp"]           (NoArg (\o -> o {target = TargetCpp}))
    "Output C++ code for use with FLex and Bison"
  , Option "" ["cpp-nostl"]     (NoArg (\o -> o {target = TargetCppNoStl}))
    "Output C++ code (without STL) for use with FLex and Bison"
  , Option "" ["csharp"]        (NoArg (\o -> o {target = TargetCSharp}))
    "Output C# code for use with GPLEX and GPPG"
  , Option "" ["ocaml"]         (NoArg (\o -> o {target = TargetOCaml}))
    "Output OCaml code for use with ocamllex and ocamlyacc"
  , Option "" ["profile"]       (NoArg (\o -> o {target = TargetProfile}))
    "Output Haskell code for rules with permutation profiles"
  , Option "" ["pygments"]      (NoArg (\o -> o {target = TargetPygments}))
    "Output a Python lexer for Pygments"
  ]

-- | A list of the options and for each of them, the target language
-- they apply to.
specificOptions :: [(OptDescr (SharedOptions -> SharedOptions), [Target])]
specificOptions =
  [ ( Option ['l'] [] (NoArg (\o -> o {linenumbers = RecordPositions}))
        "Add and set line_number field for all syntax classes\nJava requires cup 0.11b-2014-06-11 or greater"
    , [TargetCpp, TargetJava] )
  , ( Option ['p'] []
      (ReqArg (\n o -> o {inPackage = Just n}) "<namespace>")
      "Prepend <namespace> to the package/module name"
    , [TargetCpp, TargetCSharp, TargetHaskell, TargetHaskellGadt, TargetProfile, TargetJava] )
  , ( Option [] ["jflex"] (NoArg (\o -> o {javaLexerParser = JFlexCup}))
          "Lex with JFlex, parse with CUP"
    , [TargetJava] )
    , ( Option [] ["jlex"] (NoArg (\o -> o {javaLexerParser = Antlr4}))
                  "Lex with Jlex, parse with CUP (default)"
            , [TargetJava] )
    , ( Option [] ["antlr4"] (NoArg (\o -> o {javaLexerParser = Antlr4}))
              "Lex and parse with antlr4"
        , [TargetJava] )
  , ( Option [] ["vs"] (NoArg (\o -> o {visualStudio = True}))
          "Generate Visual Studio solution/project files"
    , [TargetCSharp] )
  , ( Option [] ["wcf"] (NoArg (\o -> o {wcf = True}))
          "Add support for Windows Communication Foundation,\n by marking abstract syntax classes as DataContracts"
    , [TargetCSharp] )
  , ( Option ['d'] [] (NoArg (\o -> o {inDir = True}))
          "Put Haskell code in modules Lang.* instead of Lang*"
    , [TargetHaskell, TargetHaskellGadt, TargetProfile] )
  , ( Option []    ["alex1"] (NoArg (\o -> o {alexMode = Alex1}))
          "Use Alex 1.1 as Haskell lexer tool"
    , [TargetHaskell, TargetHaskellGadt, TargetProfile] )
  , ( Option []    ["alex2"] (NoArg (\o -> o {alexMode = Alex2}))
          "Use Alex 2 as Haskell lexer tool"
    , [TargetHaskell, TargetHaskellGadt, TargetProfile] )
  , ( Option []    ["alex3"] (NoArg (\o -> o {alexMode = Alex3}))
          "Use Alex 3 as Haskell lexer tool (default)"
    , [TargetHaskell, TargetHaskellGadt, TargetProfile] )
  , ( Option []    ["sharestrings"] (NoArg (\o -> o {shareStrings = True}))
          "Use string sharing in Alex 2 lexer"
    , [TargetHaskell, TargetHaskellGadt, TargetProfile] )
  , ( Option []    ["bytestrings"] (NoArg (\o -> o {byteStrings = True}))
          "Use byte string in Alex 2 lexer"
    , [TargetHaskell, TargetHaskellGadt, TargetProfile] )
  , ( Option []    ["glr"] (NoArg (\o -> o {glr = GLR}))
          "Output Happy GLR parser"
    , [TargetHaskell, TargetHaskellGadt, TargetProfile] )
  , ( Option []    ["cnf"] (NoArg (\o -> o {cnf = True}))
          "Use the CNF parser instead of happy"
    , [TargetHaskell, TargetHaskellGadt, TargetProfile] )
  , ( Option []    ["ghc"] (NoArg (\o -> o {ghcExtensions = True}))
          "Use ghc-specific language extensions"
    , [TargetHaskell, TargetHaskellGadt, TargetProfile] )
  , ( Option []    ["functor"] (NoArg (\o -> o {functor = True}))
          "Make the AST a functor and use it to store the position of the nodes"
    , [TargetHaskell] )
  , ( Option []    ["xml"] (NoArg (\o -> o {xml = 1}))
          "Also generate a DTD and an XML printer"
    , [TargetHaskell, TargetHaskellGadt, TargetProfile] )
  , ( Option []    ["xmlt"] (NoArg (\o -> o {xml = 2}))
          "DTD and an XML printer, another encoding"
    , [TargetHaskell, TargetHaskellGadt, TargetProfile] )
  , ( Option []    ["agda"] (NoArg (\o -> o {agda = True}))
          "Also generate Agda bindings for the abstract syntax"
    , [TargetHaskell, TargetHaskellGadt, TargetProfile] )
  ]

-- | The list of specific options for a target.
specificOptions' :: Target -> [OptDescr (SharedOptions -> SharedOptions)]
specificOptions' t = map fst $ filter (elem t . snd) specificOptions

commonOptions :: [OptDescr (SharedOptions -> SharedOptions)]
commonOptions =
  [ Option "m" ["makefile"] (OptArg (setMakefile . fromMaybe "Makefile") "MAKEFILE")
      "generate Makefile"
  , Option "o" ["outputdir"] (ReqArg (\n o -> o {outDir = n}) "DIR")
      "Redirects all generated files into DIR"
  ]
  where setMakefile mf o = o { make = Just mf }

allOptions :: [OptDescr (SharedOptions -> SharedOptions)]
allOptions = targetOptions ++ commonOptions ++ map fst specificOptions

-- | All target options and all specific options for a given target.
allOptions' :: Target -> [OptDescr (SharedOptions -> SharedOptions)]
allOptions' t = targetOptions ++ commonOptions ++ specificOptions' t

-- ~~~ Help strings ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

title :: [String]
title =
  [ "The BNF Converter, " ++ showVersion version ++ " (c) 2002-today BNFC development team."
  , "Free software under GNU General Public License (GPL)."
  , "List of recent contributors at https://github.com/BNFC/bnfc/graphs/contributors."
  , "Report bugs at https://github.com/BNFC/bnfc/issues."
  , ""
  ]

oldContributors :: [String]
oldContributors =
  [ "(c) Jonas Almström Duregård, Krasimir Angelov, Jean-Philippe Bernardy, Björn Bringert, Johan Broberg, Paul Callaghan, "
  , "    Grégoire Détrez, Markus Forsberg, Ola Frid, Peter Gammie, Thomas Hallgren, Patrik Jansson, "
  , "    Kristofer Johannisson, Antti-Juhani Kaijanaho, Ulf Norell, "
  , "    Michael Pellauer and Aarne Ranta 2002 - 2013."
  ]

usage :: String
usage = "usage: bnfc [--version] [--help] <target language> [<args>] file.cf"

help :: String
help = unlines $ title ++
    [ usage
    , ""
    , usageInfo "Global options"   globalOptions
    , usageInfo "Common options"   commonOptions
    , usageInfo "Target languages" targetOptions
    ] ++ map targetUsage helpTargets
  where
  helpTargets = [TargetHaskell, TargetJava, TargetCpp, TargetCSharp ]
  targetUsage t = usageInfo
    (printf "Special options for the %s backend" (show t))
    (specificOptions' t)

-- ~~~ Parsing machinery ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-- | Main parsing function
parseMode :: [String] -> Mode
parseMode []   = Help
parseMode args =
  -- First, check for global options like --help or --version
  case getOpt' Permute globalOptions args' of
    (mode:_,_,_,_) -> mode

    -- Then, determine target language.
    _ -> case getOpt' Permute targetOptions args' of
      -- ([]     ,_,_,_) -> UsageError "No target selected"  -- --haskell is default target
      (_:_:_,_,_,_) -> UsageError "At most one target is allowed"

      -- Finally, parse options with known target.
      (optionUpdates,_,_,_) -> let
          -- Compute target and valid options for this target.
          tgt  = target (options optionUpdates)
          opts = allOptions' tgt
        in
        case getOpt' Permute opts args' of
          (_,  _, _,      e:_) -> UsageError e
          (_,  _, [u],      _) -> UsageError $ unwords [ "Unrecognized option:" , u ]
          (_,  _, us@(_:_), _) -> UsageError $ unwords $ "Unrecognized options:" : us
          (_, [], _,        _) -> UsageError "Missing grammar file"
          (optionsUpdates, [grammarFile], [], []) ->
            Target ((options optionsUpdates) {lang = takeBaseName grammarFile}) grammarFile
          (_,  _, _,        _) -> UsageError "Too many arguments"
  where
  args' = translateOldOptions args
  options optionsUpdates = foldl (.) id optionsUpdates defaultOptions


-- * Backward compatibility

-- | A translation function to maintain backward compatibility
--   with the old option syntax.

translateOldOptions :: [String] -> [String]
translateOldOptions = map $ \case
  "-agda"          ->  "--agda"
  "-java"          ->  "--java"
  "-java1.5"       ->  "--java"
  "-c"             ->  "--c"
  "-cpp"           ->  "--cpp"
  "-cpp_stl"       ->  "--cpp"
  "-cpp_no_stl"    ->  "--cpp-nostl"
  "-csharp"        ->  "--csharp"
  "-ocaml"         ->  "--ocaml"
  "-fsharp"        ->  "fsharp"
  "-haskell"       ->  "--haskell"
  "-prof"          ->  "--profile"
  "-gadt"          ->  "--haskell-gadt"
  "-alex1"         ->  "--alex1"
  "-alex2"         ->  "--alex2"
  "-alex3"         ->  "--alex3"
  "-sharestrings"  ->  "--sharestring"
  "-bytestrings"   ->  "--bytestring"
  "-glr"           ->  "--glr"
  "-xml"           ->  "--xml"
  "-xmlt"          ->  "--xmlt"
  "-vs"            ->  "--vs"
  "-wcf"           ->  "--wcf"
  other            ->  other
