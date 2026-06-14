param(
    [string]$PluginRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
)

. (Join-Path $PSScriptRoot "common.ps1")
$ctx = Get-DotnetHarnessValidationContext -PluginRoot $PluginRoot

Invoke-ValidationStep "git whitespace" {
    & git -C $ctx.PluginRoot rev-parse --show-toplevel *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Skipping git diff --check: plugin root is not in a git repository."
        return
    }

    $gitRoot = (& git -C $ctx.PluginRoot rev-parse --show-toplevel).Trim()
    $relativePluginPath = [System.IO.Path]::GetRelativePath($gitRoot, $ctx.PluginRoot).Replace("\", "/")
    & git -C $gitRoot diff --check -- $relativePluginPath
    if ($LASTEXITCODE -ne 0) {
        throw "git diff --check failed."
    }
}

Write-Host "Whitespace validation passed: $($ctx.PluginRoot)"
