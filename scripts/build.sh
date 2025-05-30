#!/bin/bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  ScriptRoot="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$ScriptRoot/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
ScriptRoot="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

architecture=''
build=false
configuration='Debug'
help=false
restore=false
solution=''
test=false
verbosity='minimal'
properties=''

while [[ $# -gt 0 ]]; do
  lower="$(echo "$1" | awk '{print tolower($0)}')"
  case $lower in
    --architecture)
      architecture=$2
      shift 2
      ;;
    --build)
      build=true
      shift 1
      ;;
    --configuration)
      configuration=$2
      shift 2
      ;;
    --help)
      help=true
      shift 1
      ;;
    --restore)
      restore=true
      shift 1
      ;;
    --solution)
      solution=$2
      shift 2
      ;;
    --test)
      test=true
      shift 1
      ;;
    --verbosity)
      verbosity=$2
      shift 2
      ;;
    *)
      properties="$properties $1"
      shift 1
      ;;
  esac
done

function Build {
  logFile="$LogDir/$configuration/build.binlog"

  if [[ -z "$properties" ]]; then
    dotnet build -c "$configuration" --no-restore -v "$verbosity" /bl:"$logFile" /err "$solution"
  else
    dotnet build -c "$configuration" --no-restore -v "$verbosity" /bl:"$logFile" /err "${properties[@]}" "$solution"
  fi

  LASTEXITCODE=$?

  if [ "$LASTEXITCODE" != 0 ]; then
    echo "'Build' failed for '$solution'"
    return "$LASTEXITCODE"
  fi
}

function CreateDirectory {
  if [ ! -d "$1" ]
  then
    mkdir -p "$1"
  fi
}

function Help {
  echo "Common settings:"
  echo "  --configuration <value>   Build configuration (Debug, Release)"
  echo "  --verbosity <value>       Msbuild verbosity (q[uiet], m[inimal], n[ormal], d[etailed], and diag[nostic])"
  echo "  --help                    Print help and exit"
  echo ""
  echo "Actions:"
  echo "  --restore                 Restore dependencies"
  echo "  --build                   Build solution"
  echo "  --test                    Run all tests in the solution"
  echo ""
  echo "Advanced settings:"
  echo "  --solution <value>        Path to solution to build"
  echo "  --architecture <value>    Test Architecture (<auto>, amd64, x64, x86, arm64, arm)"
  echo ""
  echo "Command line arguments not listed above are passed through to MSBuild."
}

function Restore {
  logFile="$LogDir/$configuration/restore.binlog"

  if [[ -z "$properties" ]]; then
    dotnet restore -v "$verbosity" /bl:"$logFile" /err "$solution"
  else
    dotnet restore -v "$verbosity" /bl:"$logFile" /err "${properties[@]}" "$solution"
  fi

  LASTEXITCODE=$?

  if [ "$LASTEXITCODE" != 0 ]; then
    echo "'Restore' failed for '$solution'"
    return "$LASTEXITCODE"
  fi
}

function Test {
  logFile="$LogDir/$configuration/test.binlog"

  if [[ -z "$properties" ]]; then
    dotnet test -c "$configuration" --no-build --no-restore -v "$verbosity" /bl:"$logFile" /err "$solution"
  else
    dotnet test -c "$configuration" --no-build --no-restore -v "$verbosity" /bl:"$logFile" /err "${properties[@]}" "$solution"
  fi

  LASTEXITCODE=$?

  if [ "$LASTEXITCODE" != 0 ]; then
    echo "'Test' failed for '$solution'"
    return "$LASTEXITCODE"
  fi
}

if $help; then
  Help
  exit 0
fi

RepoRoot="$ScriptRoot/.."

if [[ -z "$solution" ]]; then
  solution="$RepoRoot/ClangSharp.sln"
fi

ArtifactsDir="$RepoRoot/artifacts"
CreateDirectory "$ArtifactsDir"

LogDir="$ArtifactsDir/log"
CreateDirectory "$LogDir"

if [[ ! -z "$architecture" ]]; then
  export DOTNET_CLI_TELEMETRY_OPTOUT=1
  export DOTNET_MULTILEVEL_LOOKUP=0
  export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1

  DotNetInstallScript="$ArtifactsDir/dotnet-install.sh"
  wget -O "$DotNetInstallScript" "https://dot.net/v1/dotnet-install.sh"

  DotNetInstallDirectory="$ArtifactsDir/dotnet"
  CreateDirectory "$DotNetInstallDirectory"

  . "$DotNetInstallScript" --channel 8.0 --version latest --install-dir "$DotNetInstallDirectory" --architecture "$architecture"

  PATH="$DotNetInstallDirectory:$PATH:"
fi

if $restore; then
  Restore

  if [ "$LASTEXITCODE" != 0 ]; then
    return "$LASTEXITCODE"
  fi
fi

if $build; then
  Build

  if [ "$LASTEXITCODE" != 0 ]; then
    return "$LASTEXITCODE"
  fi
fi

if $test; then
  Test

  if [ "$LASTEXITCODE" != 0 ]; then
    return "$LASTEXITCODE"
  fi
fi
