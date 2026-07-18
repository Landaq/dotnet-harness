param(
    [string]$PluginRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [ValidateSet("Quick", "Full", "Core", "Harness", "Scaffold", "Upgrade", "Whitespace")]
    [string]$Mode = "Quick",
    [switch]$IncludeScaffold,
    [switch]$BrowserE2E
)

$ErrorActionPreference = "Stop"
$env:PYTHONUTF8 = "1"

$pythonEnvironment = Join-Path $PSScriptRoot "..\assets\harness\.codex\scripts\python-env.ps1"
. $pythonEnvironment
$python = Resolve-DotnetHarnessPython

$core = Join-Path $PSScriptRoot "validation\validate_release.py"
$requirements = Join-Path $PSScriptRoot "validation\requirements.txt"
$arguments = @($core, "--plugin-root", $PluginRoot, "--mode", $Mode)
if ($IncludeScaffold) { $arguments += "--include-scaffold" }
if ($BrowserE2E) { $arguments += "--browser-e2e" }

$needsYaml = $Mode -in @("Quick", "Full", "Core")
$needsPlaywright = $Mode -eq "Full" -or $BrowserE2E
if (-not $needsYaml -and -not $needsPlaywright) {
    & $python @arguments
    exit $LASTEXITCODE
}

$imports = @()
if ($needsYaml) { $imports += "yaml" }
if ($needsPlaywright) { $imports += "playwright" }
$importCommand = "import " + ($imports -join ", ")
& $python -c $importCommand 2>$null
if ($LASTEXITCODE -eq 0) {
    & $python @arguments
    exit $LASTEXITCODE
}

$uv = Get-Command uv -ErrorAction SilentlyContinue
if (-not $uv) {
    throw "Release validation dependencies are required. Install from $requirements or install uv."
}

if (-not $env:UV_CACHE_DIR) {
    $env:UV_CACHE_DIR = Join-Path ([System.IO.Path]::GetTempPath()) "dotnet-harness-uv-cache"
}
& $uv.Source run --no-project --python $python --with-requirements $requirements -- python @arguments
exit $LASTEXITCODE
