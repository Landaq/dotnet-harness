param(
    [string]$Root = (Get-Location).Path,
    [string]$ProjectName,
    [string]$ServiceName,
    [switch]$NoService,
    [switch]$HarnessOnly,
    [switch]$Preview,
    [switch]$NoGitkeep,
    [switch]$SkipHarnessUpgrade
)

$ErrorActionPreference = "Stop"
$env:PYTHONUTF8 = "1"

$pythonEnvironment = Join-Path $PSScriptRoot "assets\harness\.codex\scripts\python-env.ps1"
. $pythonEnvironment
$python = Resolve-DotnetHarnessPython

$core = Join-Path $PSScriptRoot "install.py"
if (-not (Test-Path -LiteralPath $core)) {
    throw "Missing install core: $core"
}

$arguments = @($core, "--root", $Root)
if ($ProjectName) { $arguments += @("--project-name", $ProjectName) }
if ($ServiceName) { $arguments += @("--service-name", $ServiceName) }
if ($NoService) { $arguments += "--no-service" }
if ($HarnessOnly) { $arguments += "--harness-only" }
if ($Preview) { $arguments += "--preview" }
if ($NoGitkeep) { $arguments += "--no-gitkeep" }
if ($SkipHarnessUpgrade) { $arguments += "--skip-harness-upgrade" }

& $python @arguments
exit $LASTEXITCODE
