param(
    [string]$PluginRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [ValidateSet("Quick", "Full", "Core", "Harness", "Scaffold", "Upgrade", "Whitespace")]
    [string]$Mode = "Quick",
    [switch]$IncludeScaffold
)

$ErrorActionPreference = "Stop"
$env:PYTHONUTF8 = "1"

$pluginRootPath = (Resolve-Path -LiteralPath $PluginRoot).Path
$validationRoot = Join-Path $PSScriptRoot "validation"

$scriptGroups = @{
    Core = @("validate-core.ps1")
    Harness = @("validate-harness.ps1")
    Scaffold = @("validate-scaffold.ps1")
    Upgrade = @("validate-upgrade.ps1")
    Whitespace = @("validate-whitespace.ps1")
    Quick = @(
        "validate-core.ps1",
        "validate-harness.ps1",
        "validate-upgrade.ps1",
        "validate-whitespace.ps1"
    )
    Full = @(
        "validate-core.ps1",
        "validate-harness.ps1",
        "validate-scaffold.ps1",
        "validate-upgrade.ps1",
        "validate-whitespace.ps1"
    )
}

$selectedScripts = New-Object System.Collections.Generic.List[string]
foreach ($scriptName in $scriptGroups[$Mode]) {
    $selectedScripts.Add($scriptName) | Out-Null
}
if ($IncludeScaffold -and -not $selectedScripts.Contains("validate-scaffold.ps1")) {
    $selectedScripts.Insert([Math]::Max(0, $selectedScripts.Count - 1), "validate-scaffold.ps1")
}

$failures = New-Object System.Collections.Generic.List[string]
foreach ($scriptName in $selectedScripts) {
    $scriptPath = Join-Path $validationRoot $scriptName
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        $failures.Add("Missing validation script: $scriptPath") | Out-Null
        continue
    }

    Write-Host "[group] $scriptName"
    & pwsh -NoProfile -File $scriptPath -PluginRoot $pluginRootPath
    if ($LASTEXITCODE -ne 0) {
        $failures.Add("$scriptName failed with exit code $LASTEXITCODE") | Out-Null
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Release validation failed:"
    foreach ($failure in $failures) {
        Write-Host "- $failure"
    }
    exit 1
}

Write-Host "Release validation passed ($Mode): $pluginRootPath"
