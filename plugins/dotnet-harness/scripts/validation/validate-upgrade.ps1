param(
    [string]$PluginRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
)

. (Join-Path $PSScriptRoot "common.ps1")
$ctx = Get-DotnetHarnessValidationContext -PluginRoot $PluginRoot

Invoke-ValidationStep "install script upgrade contract" {
    foreach ($scriptPath in @($ctx.InstallScript, $ctx.BootstrapScript, $ctx.UpgradeScript)) {
        $scriptText = Get-Content -LiteralPath $scriptPath -Raw
        if ($scriptText -notmatch "InstallOptionalSkills|install-optional-skills") {
            throw "Setup/upgrade path must expose optional skill installation: $scriptPath"
        }
    }

    $installText = Get-Content -LiteralPath $ctx.InstallScript -Raw
    foreach ($requiredText in @(
        'SkipHarnessUpgrade',
        'Test-ExistingHarness',
        'upgrade-harness.ps1',
        '[upgrade] existing repo-local harness detected',
        '-Apply'
    )) {
        if (-not (Test-PolicyPattern $installText $requiredText)) {
            throw "Install path must auto-run harness upgrade for existing repo-local harnesses: '$requiredText'."
        }
    }

    $upgradeText = Get-Content -LiteralPath $ctx.UpgradeScript -Raw
    foreach ($requiredText in @(".codex\harness-config.json", "[create]", "[preview] create")) {
        if (-not (Test-PolicyPattern $upgradeText $requiredText)) {
            throw "Upgrade path must create missing harness config without overwriting: '$requiredText'."
        }
    }
}

Invoke-ValidationStep "harness-only install" {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("dotnet-harness-harnessonly-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    try {
        & pwsh -NoProfile -File $ctx.InstallScript -Root $root -ProjectName "HarnessOnlySmoke" -HarnessOnly
        if ($LASTEXITCODE -ne 0) {
            throw "harness-only install failed."
        }
        foreach ($unexpected in @("src", "test")) {
            if (Test-Path -LiteralPath (Join-Path $root $unexpected)) {
                throw "harness-only install must not create $unexpected."
            }
        }
        foreach ($required in @("AGENTS.md", ".codex\agents", ".codex\scripts")) {
            if (-not (Test-Path -LiteralPath (Join-Path $root $required))) {
                throw "harness-only install missing $required."
            }
        }
    }
    finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Invoke-ValidationStep "install-driven existing harness upgrade" {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("dotnet-harness-install-upgrade-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path (Join-Path $root ".codex\agents") | Out-Null
    Set-Content -LiteralPath (Join-Path $root "AGENTS.md") -Value "# Legacy" -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $root ".codex\agents\legacy.toml") -Value @'
name = "legacy"
description = "legacy"
developer_instructions = "legacy"
model_reasoning_effort = "high"
sandbox_mode = "workspace-write"

[policy]
workflow_modes = ["legacy"]
'@ -Encoding UTF8
    try {
        & pwsh -NoProfile -File $ctx.InstallScript -Root $root -ProjectName "InstallUpgradeSmoke" -HarnessOnly
        if ($LASTEXITCODE -ne 0) {
            throw "install existing-harness upgrade failed."
        }
        $activePolicyTables = Get-ChildItem -LiteralPath (Join-Path $root ".codex\agents") -Filter "*.toml" -File |
            Select-String -Pattern "^\s*\[policy\]" -ErrorAction SilentlyContinue
        if ($activePolicyTables) {
            throw "install existing-harness upgrade left unsupported [policy] tables in active agents."
        }
        foreach ($required in @("AGENTS.md", ".codex\agents", ".codex\scripts", ".codex\backups")) {
            if (-not (Test-Path -LiteralPath (Join-Path $root $required))) {
                throw "install existing-harness upgrade missing $required."
            }
        }
    }
    finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Invoke-ValidationStep "upgrade preview/apply" {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("dotnet-harness-upgrade-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path (Join-Path $root ".codex\agents") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $root ".codex\skills\legacy") | Out-Null
    Set-Content -LiteralPath (Join-Path $root ".codex\agents\legacy.toml") -Value 'name = "legacy"' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $root ".codex\skills\legacy\SKILL.md") -Value '# Legacy' -Encoding UTF8
    try {
        & pwsh -NoProfile -File $ctx.UpgradeScript -TargetRoot $root -SourceRoot $ctx.HarnessRoot
        if ($LASTEXITCODE -ne 0) {
            throw "upgrade preview failed."
        }
        & pwsh -NoProfile -File $ctx.UpgradeScript -TargetRoot $root -SourceRoot $ctx.HarnessRoot -Apply
        if ($LASTEXITCODE -ne 0) {
            throw "upgrade apply failed."
        }
        if (Test-Path -LiteralPath (Join-Path $root ".codex\skills")) {
            throw "upgrade apply must remove active .codex\skills."
        }
        foreach ($required in @(".gitignore", ".gitattributes", ".codex\harness-config.json", ".codex\agents", ".codex\scripts")) {
            if (-not (Test-Path -LiteralPath (Join-Path $root $required))) {
                throw "upgrade apply missing $required."
            }
        }
    }
    finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "Upgrade validation passed: $($ctx.PluginRoot)"
