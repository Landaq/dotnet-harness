param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [string]$PluginRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,

    [switch]$Apply
)

$ErrorActionPreference = "Stop"

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Version must be SemVer core format, for example 0.4.12."
}

$pluginRootPath = (Resolve-Path -LiteralPath $PluginRoot).Path
$manifestPath = Join-Path $pluginRootPath ".codex-plugin\plugin.json"
$versionPath = Join-Path $pluginRootPath "VERSION.md"

if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Missing plugin manifest: $manifestPath"
}
if (-not (Test-Path -LiteralPath $versionPath)) {
    throw "Missing VERSION.md: $versionPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$currentManifestVersion = [string]$manifest.version
$versionText = Get-Content -LiteralPath $versionPath -Raw
$currentVersionMatch = [regex]::Match($versionText, 'Current version:\s*`(?<version>[^`]+)`')
if (-not $currentVersionMatch.Success) {
    throw 'VERSION.md must contain: Current version: `<version>`'
}
$currentVersion = $currentVersionMatch.Groups["version"].Value

Write-Host "[current] plugin.json: $currentManifestVersion"
Write-Host "[current] VERSION.md: $currentVersion"
Write-Host "[target]  $Version"

if (-not $Apply) {
    Write-Host "[preview] no files changed. Re-run with -Apply to update version fields."
    return
}

$manifest.version = $Version
$manifestJson = $manifest | ConvertTo-Json -Depth 20
Set-Content -LiteralPath $manifestPath -Value $manifestJson -Encoding utf8

$updatedVersionText = [regex]::Replace(
    $versionText,
    'Current version:\s*`[^`]+`',
    ('Current version: `' + $Version + '`'),
    1
)
Set-Content -LiteralPath $versionPath -Value $updatedVersionText -Encoding utf8

Write-Host "[updated] $manifestPath"
Write-Host "[updated] $versionPath"
