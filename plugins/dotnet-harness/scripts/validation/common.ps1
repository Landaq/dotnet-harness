# Deprecated compatibility library. Release validation now uses validate_release.py.
$ErrorActionPreference = "Stop"
$env:PYTHONUTF8 = "1"

function ConvertTo-PolicyPattern {
    param([string]$Text)

    $tokens = [regex]::Matches($Text, "[\p{L}\p{N}_@/$%+.-]+") |
        ForEach-Object { [regex]::Escape($_.Value) }
    if (-not $tokens -or $tokens.Count -eq 0) {
        return [regex]::Escape($Text)
    }

    return "(?is)" + ($tokens -join "[\s\S]{0,120}")
}

function Test-PolicyPattern {
    param(
        [string]$Content,
        [string]$Text
    )

    return $Content -match (ConvertTo-PolicyPattern $Text)
}

function Invoke-ValidationStep {
    param(
        [string]$Name,
        [scriptblock]$Body
    )

    Write-Host "[check] $Name"
    & $Body
}

function Get-DotnetHarnessValidationContext {
    param([string]$PluginRoot)

    $pluginRootPath = (Resolve-Path -LiteralPath $PluginRoot).Path
    $skillsRoot = Join-Path $pluginRootPath "skills"
    $harnessRoot = Join-Path $pluginRootPath "assets\harness"
    $codexHome = if ($env:CODEX_HOME) {
        $env:CODEX_HOME
    }
    else {
        Join-Path ([Environment]::GetFolderPath("UserProfile")) ".codex"
    }

    return [pscustomobject]@{
        PluginRoot = $pluginRootPath
        PluginValidator = Join-Path $codexHome "skills\.system\plugin-creator\scripts\validate_plugin.py"
        SkillValidator = Join-Path $codexHome "skills\.system\skill-creator\scripts\quick_validate.py"
        HarnessValidator = Join-Path $harnessRoot ".codex\scripts\validate-task-agents.ps1"
        HarnessValidatorCore = Join-Path $harnessRoot ".codex\scripts\validate_task_agents.py"
        MacHarnessValidator = Join-Path $harnessRoot ".codex\scripts\validate-task-agents.zsh"
        HarnessRoot = $harnessRoot
        SkillsRoot = $skillsRoot
        TaskAgentsSkill = Join-Path $skillsRoot "task-agents\SKILL.md"
        ManifestPath = Join-Path $pluginRootPath ".codex-plugin\plugin.json"
        HarnessConfig = Join-Path $harnessRoot ".codex\harness-config.json"
        InstallScript = Join-Path $pluginRootPath "install.ps1"
        InstallCore = Join-Path $pluginRootPath "install.py"
        MacInstallScript = Join-Path $pluginRootPath "install.zsh"
        BootstrapScript = Join-Path $skillsRoot "project-structure-setup\scripts\bootstrap_project_structure.py"
        PackageVersionsManifest = Join-Path $skillsRoot "project-structure-setup\references\package-versions.json"
        UpgradeScript = Join-Path $harnessRoot ".codex\scripts\upgrade-harness.ps1"
        UpgradeCore = Join-Path $harnessRoot ".codex\scripts\upgrade_harness.py"
        MacUpgradeScript = Join-Path $harnessRoot ".codex\scripts\upgrade-harness.zsh"
        PythonEnvPowerShell = Join-Path $harnessRoot ".codex\scripts\python-env.ps1"
        PythonEnvScript = Join-Path $harnessRoot ".codex\scripts\python-env.zsh"
        ReleaseValidatorCore = Join-Path $pluginRootPath "scripts\validation\validate_release.py"
        MacReleaseValidator = Join-Path $pluginRootPath "scripts\validate-release.zsh"
        ValidationRequirements = Join-Path $pluginRootPath "scripts\validation\requirements.txt"
        ReleaseHelperScript = Join-Path $pluginRootPath "scripts\release-helper.ps1"
    }
}

function Invoke-CheckedCommand {
    param(
        [string]$Name,
        [string[]]$Command
    )

    Write-Host "[smoke] $Name"
    $executable = $Command[0]
    $arguments = @($Command | Select-Object -Skip 1)
    & $executable @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE."
    }
}
