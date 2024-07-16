{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}

module Cardano.Beacon.Run (
    ConsoleStyle (..)
  , RunEnvironment (..)
  , envBeaconDir
  , envEchoing
  , envEmpty
  , shellCurlGitHubAPI
  , shellMergeMetaAndData
  , shellNixBuildVersion
  , shellRunDbAnalyser
  ) where

import           Cardano.Beacon.Chain
import           Cardano.Beacon.CLI (BeaconOptions (..))
import           Cardano.Beacon.Console
import           Cardano.Beacon.Types
import           Control.Exception (SomeException (..), try)
import           Control.Monad (void, when)
import           Data.Bool (bool)
import           Data.ByteString.Char8 as BSC (ByteString, pack, readFile,
                     unpack, writeFile)
import           Data.Maybe (fromJust)
import           System.Directory (createDirectoryIfMissing, doesFileExist,
                     removeFile)
import           System.FilePath (isRelative, (</>))
import           System.Process hiding (env)


data RunEnvironment = Env
  { runChains  :: Maybe Chains
  , runCommit  :: Maybe CommitInfo
  , runInstall :: Maybe InstallInfo
  , runOptions :: BeaconOptions
  }

envEchoing :: RunEnvironment -> EchoCommand
envEchoing = optEchoing . runOptions

envBeaconDir :: RunEnvironment -> FilePath
envBeaconDir = optBeaconDir . runOptions

envEmpty :: BeaconOptions -> RunEnvironment
envEmpty = Env Nothing Nothing Nothing



runShellEchoing :: EchoCommand -> String -> [String] -> IO String
runShellEchoing echo cmd args = do
  when (echo == EchoCommand) $
    printStyled StyleEcho asOneLine
  try (readCreateProcess (shell asOneLine) "") >>= \case
    Left (SomeException e)      -> printFatalAndDie $ show e
    Right out                   -> pure out
  where
    asOneLine = concat [cmd, " ", unwords args]

-- cf. https://docs.github.com/en/rest/commits/commits?apiVersion=2022-11-28#get-a-commit
shellCurlGitHubAPI :: RunEnvironment -> String -> IO ByteString
shellCurlGitHubAPI env queryPath = do
  _ <- runShellEchoing (envEchoing env) "curl" curlArgs
  result <- BSC.readFile tempFile
  removeFile tempFile
  pure result
  where
    tempFile = envBeaconDir env </> "temp.curl.json"
    curlArgs =
      [ "-s -L"
      , "-H \"Accept: application/vnd.github+json\""
      , "-H \"X-GitHub-Api-Version: 2022-11-28\""
      , "-o", tempFile
      , "https://api.github.com" ++ queryPath
      ]

shellNixBuildVersion :: RunEnvironment -> Version -> IO InstallInfo
shellNixBuildVersion env ver@Version{verCompiler = compiler} = do
  exists <- doesFileExist install
  if exists
    then printStyled StyleInfo "target binary already built and linked"
    else do
      createDirectoryIfMissing False binDir
      void $ runShellEchoing echoing "nix" nixBuildArgs

  nix_path <- runShellEchoing echoing "readlink" [output]
  return $ InstallInfo install (head . lines $ nix_path) ver
  where
    echoing = envEchoing env
    sha     = ciCommitSHA1 . fromJust . runCommit $ env
    binName = take 9 sha ++ "-" ++ compiler
    binDir  = envBeaconDir env </> "bin"
    output  = binDir </> binName
    install = output </> "bin" </> "db-analyser"

    nixBuildArgs =
      [ "build"
      , "github:IntersectMBO/ouroboros-consensus/"
          ++ sha
          ++ "#hydraJobs.x86_64-linux.native."
          ++ compiler
          ++ ".exesNoAsserts.ouroboros-consensus-cardano.db-analyser"
      , "-o", output
      ]

shellRunDbAnalyser :: RunEnvironment -> BeaconChain -> FilePath -> IO ()
shellRunDbAnalyser env BeaconChain{..} outFile = do
  onlyImmutableFlag <-
    whenTrue "--only-immutable-db" <$> detectDbAnalyserNeedsOnlyImmutable env

  _ <- runShellEchoing echoing dbAnalyser (dbAnalyserArgs <> onlyImmutableFlag)
  callJQ echoing outFile jqToListArgs
  removeFile tempResult
  where
    -- These are the compiled-in options specified in cardano-node.cabal, used for relese builds.
    -- We adhere to those for maximum fidelity of beacon benchmarks.
    rtsOpts = "-T -I0 -A16m -N2 --disable-delayed-os-memory-return"

    dbAnalyser  = installPath . fromJust . runInstall $ env
    tempResult  = envBeaconDir env </> "temp.result.json"
    echoing     = envEchoing env
    chDir
      | isRelative chHomeDir  = envBeaconDir env </> "chain" </> chHomeDir
      | otherwise             = chHomeDir

    dbAnalyserArgs = filter (not . null)
      [ "--db", chDir </> chDbDir
      , maybe "" (\s -> "--analyse-from " ++ show s) chFromSlot
      , "--benchmark-ledger-ops"
      , "--out-file", tempResult
      , maybe "" (\b -> "--num-blocks-to-process " ++ show b) chProcessBlocks
      , "cardano"
      , "--config", chDir </> chConfigFile
      , "+RTS", rtsOpts, "-RTS"
      ]

    jqToListArgs =
      [ "-M"
      , "'map(inputs)'"
      , tempResult
      ]

    whenTrue t = bool [] [t]

detectDbAnalyserNeedsOnlyImmutable :: RunEnvironment -> IO Bool
detectDbAnalyserNeedsOnlyImmutable env = do
  out <- runShellEchoing echoing dbAnalyser ["--help"]
  return $ "--only-immutable-db" `elem` words out
  where
    dbAnalyser  = installPath . fromJust . runInstall $ env
    echoing     = envEchoing env

shellMergeMetaAndData :: RunEnvironment -> FilePath -> FilePath -> FilePath -> IO ()
shellMergeMetaAndData env srcMeta srcData dest =
  callJQ (envEchoing env) dest
    [ "-M"
    , "'{\"meta\": $meta[0], \"data\": $data[0]}'"
    , "--slurpfile", "meta", srcMeta
    , "--slurpfile", "data", srcData
    , "--null-input"
    ]

callJQ :: EchoCommand -> FilePath -> [String] -> IO ()
callJQ echoing dest jqArgs = do
  out <- BSC.pack <$> runShellEchoing echoing "jq" jqArgs
  BSC.writeFile dest out
