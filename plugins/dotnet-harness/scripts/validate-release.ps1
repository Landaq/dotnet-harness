param(
    [string]$PluginRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$env:PYTHONUTF8 = "1"

$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([string]$Message)
    $failures.Add($Message) | Out-Null
}

function Invoke-ValidationStep {
    param(
        [string]$Name,
        [scriptblock]$Body
    )

    Write-Host "[check] $Name"
    try {
        & $Body
    }
    catch {
        Add-Failure "$Name failed: $($_.Exception.Message)"
    }
}

$pluginRootPath = (Resolve-Path -LiteralPath $PluginRoot).Path
$pluginValidator = Join-Path $env:USERPROFILE ".codex\skills\.system\plugin-creator\scripts\validate_plugin.py"
$skillValidator = Join-Path $env:USERPROFILE ".codex\skills\.system\skill-creator\scripts\quick_validate.py"
$harnessValidator = Join-Path $pluginRootPath "assets\harness\.codex\scripts\validate-task-agents.ps1"
$harnessRoot = Join-Path $pluginRootPath "assets\harness"
$skillsRoot = Join-Path $pluginRootPath "skills"
$taskAgentsSkill = Join-Path $skillsRoot "task-agents\SKILL.md"
$manifestPath = Join-Path $pluginRootPath ".codex-plugin\plugin.json"

Invoke-ValidationStep "plugin manifest" {
    if (-not (Test-Path -LiteralPath $pluginValidator)) {
        throw "Missing plugin validator: $pluginValidator"
    }
    & python $pluginValidator $pluginRootPath
    if ($LASTEXITCODE -ne 0) {
        throw "Plugin manifest validation failed."
    }
}

Invoke-ValidationStep "harness task agents" {
    if (-not (Test-Path -LiteralPath $harnessValidator)) {
        throw "Missing harness validator: $harnessValidator"
    }
    & pwsh -NoProfile -File $harnessValidator -RepoRoot $harnessRoot
    if ($LASTEXITCODE -ne 0) {
        throw "Harness task agent validation failed."
    }
}

Invoke-ValidationStep "plugin skills" {
    if (-not (Test-Path -LiteralPath $skillValidator)) {
        throw "Missing skill validator: $skillValidator"
    }

    foreach ($skillDir in Get-ChildItem -LiteralPath $skillsRoot -Directory) {
        if (Test-Path -LiteralPath (Join-Path $skillDir.FullName "SKILL.md")) {
            & python $skillValidator $skillDir.FullName
            if ($LASTEXITCODE -ne 0) {
                throw "Skill validation failed: $($skillDir.Name)"
            }
        }
    }
}

Invoke-ValidationStep "packaging hygiene" {
    $legacySkillFiles = @(Get-ChildItem -LiteralPath $skillsRoot -Recurse -File -Filter "SKILL.original.md")
    if ($legacySkillFiles.Count -gt 0) {
        throw "Remove legacy SKILL.original.md files before release."
    }

    $manifest = Get-Content -LiteralPath $manifestPath -Raw
    if ($manifest -match "TaskResult|Task Result") {
        throw "TaskResult must not be a default plugin prompt."
    }

    $taskAgents = Get-Content -LiteralPath $taskAgentsSkill -Raw
    if ($taskAgents -match "Before final response,\s*write the Task Result") {
        throw "TaskResult artifact must be opt-in, not mandatory."
    }

    foreach ($requiredText in @(
        "Agent Execution Contract",
        "Subagent delegation",
        "Delegation",
        "must use actual subagents",
        "Agent execution fallback: unavailable",
        "allowed paths and forbidden paths",
        "instruction to avoid git operations"
    )) {
        if ($taskAgents -notmatch [regex]::Escape($requiredText)) {
            throw "Task Agents must define actual subagent delegation behavior: missing '$requiredText'."
        }
    }

    if (Test-Path -LiteralPath (Join-Path $harnessRoot ".codex\skills")) {
        throw "Harness assets must not package repo-local .codex\skills."
    }

    $harnessPolicyFiles = @(
        Get-Item -LiteralPath (Join-Path $harnessRoot "AGENTS.md")
        Get-ChildItem -LiteralPath (Join-Path $harnessRoot ".codex\agents") -File -Filter "*.toml"
    )
    $localSkillRefs = $harnessPolicyFiles | Select-String -Pattern "\.codex[/\\]skills" -ErrorAction SilentlyContinue
    if ($localSkillRefs) {
        throw "Harness agents/AGENTS.md must reference dotnet-harness:* plugin skills, not .codex/skills."
    }
}

Invoke-ValidationStep "git whitespace" {
    & git -C $pluginRootPath rev-parse --show-toplevel *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Skipping git diff --check: plugin root is not in a git repository."
        return
    }

    $gitRoot = (& git -C $pluginRootPath rev-parse --show-toplevel).Trim()
    $relativePluginPath = [System.IO.Path]::GetRelativePath($gitRoot, $pluginRootPath).Replace("\", "/")
    & git -C $gitRoot diff --check -- $relativePluginPath
    if ($LASTEXITCODE -ne 0) {
        throw "git diff --check failed."
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Release validation failed:"
    foreach ($failure in $failures) {
        Write-Host "- $failure"
    }
    exit 1
}

Write-Host "Release validation passed: $pluginRootPath"
