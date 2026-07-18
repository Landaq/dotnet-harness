param(
    [string]$PluginRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
)

$entrypoint = Join-Path $PSScriptRoot "..\validate-release.ps1"
& $entrypoint -PluginRoot $PluginRoot -Mode Whitespace
exit $LASTEXITCODE
