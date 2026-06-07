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
$optionalCavemanSkill = Join-Path $pluginRootPath "assets\optional-skills\caveman\SKILL.md"
$ensureCavemanScript = Join-Path $harnessRoot ".codex\scripts\ensure-caveman-skill.ps1"
$installScript = Join-Path $pluginRootPath "install.ps1"
$bootstrapScript = Join-Path $skillsRoot "project-structure-setup\scripts\bootstrap_project_structure.py"
$upgradeScript = Join-Path $harnessRoot ".codex\scripts\upgrade-harness.ps1"

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

    $currentDocs = @(
        Join-Path $pluginRootPath "README.md"
        Join-Path $skillsRoot "architecture-workflow-guardrails\SKILL.md"
        Join-Path $skillsRoot "architecture-workflow-guardrails\references\workflow-guide.md"
        Join-Path $skillsRoot "project-structure-setup\SKILL.md"
    )
    $staleDocRefs = $currentDocs |
        Where-Object { Test-Path -LiteralPath $_ } |
        Select-String -Pattern "repo-local skills|docs/wkTask|python scripts/bootstrap_project_structure.py" -ErrorAction SilentlyContinue
    if ($staleDocRefs) {
        throw "Current plugin docs contain stale repo-local skill, default plan artifact, or direct Python CLI guidance."
    }

    foreach ($requiredText in @(
        'Agent Execution Contract',
        'Compressed Agent Handoff',
        'Mandatory Socratic Checkpoint',
        'Subagent Utilization Floor',
        'Subagent delegation',
        'Delegation',
        'default is delegation, not local-only execution',
        'For complex or multi-step work, spawn at least one read-only specialist subagent before implementation unless fallback or an explicit skip condition applies.',
        'Spawn at least one pre-implementation specialist subagent',
        'spawn at least one post-implementation subagent',
        'Only an actual delegated subagent task counts',
        'Delegation: skipped',
        'No-spawn decisions must include the exact reason.',
        'Limit pre-implementation read-only subagents to three unless the user explicitly approves more.',
        'Delegate implementation only when write sets are disjoint and requirements are settled.',
        'utilization floor satisfied',
        'Socratic',
        'Ask at least one Korean Socratic question',
        'Print `Socratic: skipped`',
        'target average ambiguity `<= 8%`',
        'must use actual subagents',
        'Agent execution fallback: unavailable',
        'allowed paths and forbidden paths',
        'instruction to avoid git operations',
        'Use `caveman full` only for internal subagent handoff prompts and subagent return summaries.',
        'Do not use `caveman full` for user-facing Socratic questions',
        'Compressed handoffs must preserve exact file paths, commands, errors, API names',
        'Mode: caveman full',
        'Findings:',
        'Changes:',
        'Risks:',
        'Verify:',
        'Next:'
    )) {
        if ($taskAgents -notmatch [regex]::Escape($requiredText)) {
            throw "Task Agents must define actual subagent delegation behavior: missing '$requiredText'."
        }
    }

    $agentFiles = @(
        Join-Path $harnessRoot ".codex\agents\08-implementation-coordinator.toml"
        Join-Path $harnessRoot ".codex\agents\09-code-reviewer.toml"
        Join-Path $harnessRoot ".codex\agents\10-verification-runner.toml"
    )
    foreach ($agentFile in $agentFiles) {
        $agentText = Get-Content -LiteralPath $agentFile -Raw
        foreach ($requiredText in @(
            'caveman full',
            'Findings',
            'Changes',
            'Risks',
            'Verify',
            'Next',
            'Preserve exact file paths, commands, errors, API names'
        )) {
            if ($agentText -notmatch [regex]::Escape($requiredText)) {
                throw "Agent must define compressed handoff behavior: $agentFile missing '$requiredText'."
            }
        }
    }

    if (Test-Path -LiteralPath (Join-Path $harnessRoot ".codex\skills")) {
        throw "Harness assets must not package repo-local .codex\skills."
    }

    foreach ($requiredPath in @($optionalCavemanSkill, $ensureCavemanScript)) {
        if (-not (Test-Path -LiteralPath $requiredPath)) {
            throw "Missing optional caveman skill support file: $requiredPath"
        }
    }

    $ensureCaveman = Get-Content -LiteralPath $ensureCavemanScript -Raw
    foreach ($requiredText in @(
        'SkillRoot = (Join-Path $HOME ".agents\skills\caveman")',
        '[preview] caveman skill missing',
        'Refusing to overwrite existing skill directory',
        '-SkillSource <path-to-caveman-skill>'
    )) {
        if ($ensureCaveman -notmatch [regex]::Escape($requiredText)) {
            throw "Caveman optional skill helper missing required behavior: '$requiredText'."
        }
    }

    foreach ($scriptPath in @($installScript, $bootstrapScript, $upgradeScript)) {
        $scriptText = Get-Content -LiteralPath $scriptPath -Raw
        if ($scriptText -notmatch "InstallOptionalSkills|install-optional-skills") {
            throw "Setup/upgrade path must expose optional skill installation: $scriptPath"
        }
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
