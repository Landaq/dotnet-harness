param(
    [string]$TargetRoot = (Get-Location).Path,
    [string]$SourceRoot,
    [switch]$Apply,
    [switch]$SkipValidation
)

$ErrorActionPreference = "Stop"
$env:PYTHONUTF8 = "1"

. (Join-Path $PSScriptRoot "python-env.ps1")
$python = Resolve-DotnetHarnessPython

$core = Join-Path $PSScriptRoot "upgrade_harness.py"
$coreArgs = @($core, "--target-root", $TargetRoot)

if ($SourceRoot) {
    $coreArgs += @("--source-root", $SourceRoot)
}
if ($Apply) {
    $coreArgs += "--apply"
}
if ($SkipValidation) {
    $coreArgs += "--skip-validation"
}

& $python @coreArgs
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
