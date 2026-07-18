param(
    [string]$PluginRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
)

. (Join-Path $PSScriptRoot "common.ps1")
$ctx = Get-DotnetHarnessValidationContext -PluginRoot $PluginRoot

Invoke-ValidationStep "plugin manifest" {
    if (-not (Test-Path -LiteralPath $ctx.PluginValidator)) {
        throw "Missing plugin validator: $($ctx.PluginValidator)"
    }
    & python $ctx.PluginValidator $ctx.PluginRoot
    if ($LASTEXITCODE -ne 0) {
        throw "Plugin manifest validation failed."
    }
}

Invoke-ValidationStep "plugin skills" {
    if (-not (Test-Path -LiteralPath $ctx.SkillValidator)) {
        throw "Missing skill validator: $($ctx.SkillValidator)"
    }

    foreach ($skillDir in Get-ChildItem -LiteralPath $ctx.SkillsRoot -Directory) {
        if (Test-Path -LiteralPath (Join-Path $skillDir.FullName "SKILL.md")) {
            & python $ctx.SkillValidator $skillDir.FullName
            if ($LASTEXITCODE -ne 0) {
                throw "Skill validation failed: $($skillDir.Name)"
            }
        }
    }
}

Invoke-ValidationStep "version consistency" {
    $manifest = Get-Content -LiteralPath $ctx.ManifestPath -Raw | ConvertFrom-Json
    $manifestVersion = [string]$manifest.version
    $versionText = Get-Content -LiteralPath (Join-Path $ctx.PluginRoot "VERSION.md") -Raw
    $versionMatch = [regex]::Match($versionText, 'Current version:\s*`(?<version>[^`]+)`')
    if (-not $versionMatch.Success) {
        throw "VERSION.md must contain a Current version line."
    }

    $versionFileVersion = $versionMatch.Groups["version"].Value
    if ($manifestVersion -ne $versionFileVersion) {
        throw "plugin.json version '$manifestVersion' does not match VERSION.md '$versionFileVersion'."
    }
    if (-not (Test-Path -LiteralPath $ctx.ReleaseHelperScript)) {
        throw "Missing release helper: $($ctx.ReleaseHelperScript)"
    }
}

Invoke-ValidationStep "packaging hygiene" {
    foreach ($requiredPath in @(
        $ctx.InstallScript,
        $ctx.InstallCore,
        $ctx.MacInstallScript,
        $ctx.UpgradeScript,
        $ctx.UpgradeCore,
        $ctx.MacUpgradeScript,
        $ctx.HarnessValidator,
        $ctx.HarnessValidatorCore,
        $ctx.MacHarnessValidator,
        $ctx.PythonEnvPowerShell,
        $ctx.PythonEnvScript,
        $ctx.ReleaseValidatorCore,
        $ctx.MacReleaseValidator,
        $ctx.ValidationRequirements
    )) {
        if (-not (Test-Path -LiteralPath $requiredPath)) {
            throw "Missing platform support file: $requiredPath"
        }
    }

    foreach ($lineEndingSource in @(
        (Join-Path $ctx.PluginRoot "..\..\.gitattributes"),
        (Join-Path $ctx.HarnessRoot ".gitattributes"),
        $ctx.BootstrapScript
    )) {
        $lineEndingText = Get-Content -LiteralPath $lineEndingSource -Raw
        if ($lineEndingText -notmatch [regex]::Escape("*.zsh text eol=lf")) {
            throw "Missing zsh LF policy: $lineEndingSource"
        }
    }

    $legacySkillFiles = @(Get-ChildItem -LiteralPath $ctx.SkillsRoot -Recurse -File -Filter "SKILL.original.md")
    if ($legacySkillFiles.Count -gt 0) {
        throw "Remove legacy SKILL.original.md files before release."
    }

    $manifest = Get-Content -LiteralPath $ctx.ManifestPath -Raw
    if ($manifest -match "TaskResult|Task Result") {
        throw "TaskResult must not be a default plugin prompt."
    }

    $taskAgentsReferences = Join-Path (Split-Path -Path $ctx.TaskAgentsSkill -Parent) "references"
    foreach ($referenceName in @(
        "workflow-modes.md",
        "phase-contracts.md",
        "delegation-policy.md",
        "worker-policy.md",
        "domain-policies.md",
        "task-result-and-git.md"
    )) {
        $referencePath = Join-Path $taskAgentsReferences $referenceName
        if (-not (Test-Path -LiteralPath $referencePath)) {
            throw "Missing Task Agents reference: $referencePath"
        }
    }

    $currentDocs = @(
        Join-Path $ctx.PluginRoot "README.md"
        Join-Path $ctx.SkillsRoot "project-structure-setup\SKILL.md"
    )
    $staleDocRefs = $currentDocs |
        Where-Object { Test-Path -LiteralPath $_ } |
        Select-String -Pattern "repo-local skills|docs/wkTask|python scripts/bootstrap_project_structure.py" -ErrorAction SilentlyContinue
    if ($staleDocRefs) {
        throw "Current plugin docs contain stale repo-local skill, default plan artifact, or direct Python CLI guidance."
    }

    if (Test-Path -LiteralPath (Join-Path $ctx.HarnessRoot ".codex\skills")) {
        throw "Harness assets must not package repo-local .codex\skills."
    }
}

Invoke-ValidationStep "package version manifest" {
    if (-not (Test-Path -LiteralPath $ctx.PackageVersionsManifest)) {
        throw "Missing package version manifest: $($ctx.PackageVersionsManifest)"
    }

    $manifest = Get-Content -LiteralPath $ctx.PackageVersionsManifest -Raw | ConvertFrom-Json
    if (-not $manifest.packages) {
        throw "package-versions.json must contain a packages object."
    }

    foreach ($packageName in @(
        "Aspire.Hosting.AppHost",
        "Aspire.Hosting.SqlServer",
        "Aspire.Hosting.Redis",
        "Microsoft.AspNetCore.Components.WebAssembly",
        "Microsoft.AspNetCore.Components.WebAssembly.Server",
        "Microsoft.EntityFrameworkCore.SqlServer",
        "Microsoft.AspNetCore.OpenApi",
        "Microsoft.Extensions.DependencyInjection.Abstractions",
        "MudBlazor",
        "Scalar.AspNetCore",
        "Yarp.ReverseProxy",
        "Microsoft.NET.Test.Sdk",
        "xunit"
    )) {
        if (-not $manifest.packages.PSObject.Properties[$packageName]) {
            throw "package-versions.json missing required package: $packageName"
        }
    }

    $bootstrapText = Get-Content -LiteralPath $ctx.BootstrapScript -Raw
    foreach ($requiredText in @("package-versions.json", "_package_versions_props", "json.load")) {
        if (-not (Test-PolicyPattern $bootstrapText $requiredText)) {
            throw "bootstrap must generate Directory.Packages.props from package-versions.json: missing '$requiredText'."
        }
    }
}

Write-Host "Core validation passed: $($ctx.PluginRoot)"
