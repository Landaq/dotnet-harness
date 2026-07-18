param(
    [string]$PluginRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [ValidateSet("Quick", "Full", "Core", "Harness", "Scaffold", "Upgrade", "Whitespace")]
    [string]$Mode = "Quick",
    [switch]$IncludeScaffold
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

$needsYaml = $Mode -in @("Quick", "Full", "Core")
if (-not $needsYaml) {
    & $python @arguments
    exit $LASTEXITCODE
}

& $python -c "import yaml" 2>$null
if ($LASTEXITCODE -eq 0) {
    & $python @arguments
    exit $LASTEXITCODE
}

$uv = Get-Command uv -ErrorAction SilentlyContinue
if (-not $uv) {
    throw "PyYAML is required. Install validation dependencies from $requirements or install uv."
}

if (-not $env:UV_CACHE_DIR) {
    $env:UV_CACHE_DIR = Join-Path ([System.IO.Path]::GetTempPath()) "dotnet-harness-uv-cache"
}
& $uv.Source run --no-project --python $python --with-requirements $requirements -- python @arguments
exit $LASTEXITCODE
