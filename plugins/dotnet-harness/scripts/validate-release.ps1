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
        'Agent-First Orchestration',
        'Delegation Evidence',
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
        'Actual subagent execution means calling an available delegated-agent tool such as `spawn_agent`',
        'Before fallback, inspect active callable tools.',
        'Do not report `Agent execution fallback: unavailable` while such a tool is callable.',
        'Tool availability checked:',
        'Callable Namespace:',
        'Tool Call Receipt:',
        'Tool Result Status:',
        '`Delegation: used` is valid only when backed by an actual tool-call receipt',
        'Do not synthesize this block from a delegation plan.',
        'Reading agent TOML, summarizing an agent persona, or role-playing a specialist in the main thread does not count as subagent execution.',
        'Delegation: used',
        'Do not mark utilization satisfied from planned delegation, simulated agent reasoning, or reading `.codex/agents/*.toml`.',
        'main-thread-only execution while subagent tooling is available is noncompliant',
        'Delegation: skipped',
        'No-spawn decisions must include the exact reason.',
        'Main thread is the orchestrator, not the default implementer, for non-trivial work when task-agents is active.',
        'Agent-first means planning, implementation, review, and verification should be delegated to discovered repo-local agents whenever the task is non-trivial and subagent capability is available.',
        'Agent-first handoff is the default for non-trivial dotnet-harness work. The user does not need to explicitly request subagent handoff.',
        'When task-agents is active, the main thread is a coordinator/reporter, not the default implementer.',
        'Subagents own staged analysis, implementation, review, and verification. Main thread edits are exceptions and must be reported.',
        'Each subagent output must be treated as the input contract for the next stage.',
        'TaskResult remains opt-in only.',
        'Direct main-thread edits are allowed only for small fixes, integration of agent output, or non-overlapping unblock work.',
        'If the user explicitly invokes `@dotnet-harness` for non-trivial work, treat the request as task-agents active and agent-first unless the user explicitly opts out of agents.',
        'Non-trivial work means multi-step, multi-file, architecture/workflow/plugin/harness change, backend/frontend behavior change, test strategy, review, verification, CI, release-sensitive, or unclear approval-boundary work.',
        'Main-thread direct work is allowed for a direct answer, status check, trivial one-file fix, or explicit agent opt-out.',
        'If the user says `에이전트 쓰지마`, `no agents`, or equivalent explicit opt-out, do not spawn subagents; report `Delegation: skipped user-opt-out` and continue main-thread direct.',
        'Strict staged handoff order',
        'Subagent output as next input',
        'For backend non-trivial work, spawn `service-template` and `tdd-test` as read-only specialists before implementation unless fallback, explicit opt-out, or a concrete skip condition applies.',
        '/feedback',
        '에이전트들이 전반적으로 수행',
        'If no agent is called, report why briefly with `Delegation: skipped <reason>`.',
        'If agent questions, evidence duties, or write sets overlap, merge them, serialize them, or skip the duplicate role with `Delegation: skipped coupled`.',
        'While subagents are running, do not duplicate their implementation scope in the main thread.',
        'Agents Used',
        'Agents Skipped',
        'Agent Results Reflected',
        'Git`: `not requested; git-operator not used',
        'TaskResult`: `not requested; not created',
        'Limit pre-implementation read-only subagents to three unless the user explicitly approves more.',
        'Delegate implementation only when write sets are disjoint and requirements are settled.',
        'utilization floor satisfied',
        'Socratic',
        'Ask at least one Korean Socratic question',
        'Print `Socratic: skipped`',
        'Socratic: satisfied',
        'target average ambiguity `<= 8%`',
        'Recalculate ambiguity percentage for each active feature goal and the average ambiguity after every answer.',
        'Check goal alignment after every answer',
        'Continue this answer -> reassess -> ask loop until average ambiguity is `<= 8%`',
        'After every user answer, restate the updated goal boundary, recalculate each feature ambiguity %, recalculate average ambiguity %, and check whether the answer still aligns with the active goal.',
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
        Join-Path $harnessRoot ".codex\agents\03-service-template.toml"
        Join-Path $harnessRoot ".codex\agents\04-frontend-ui.toml"
        Join-Path $harnessRoot ".codex\agents\05-tdd-test.toml"
        Join-Path $harnessRoot ".codex\agents\06-reference-auditor.toml"
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

    $intakePlanner = Join-Path $harnessRoot ".codex\agents\07-intake-planner.toml"
    $intakePlannerText = Get-Content -LiteralPath $intakePlanner -Raw
    foreach ($requiredText in @(
        '@dotnet-harness',
        '$dotnet-harness',
        'dotnet-harness',
        '/feedback',
        '에이전트들이 전반적으로 수행',
        '에이전트 쓰지마',
        'agent-first orchestration request',
        'planning, implementation, feedback/code-review, and verification should be assigned to discovered repo-local agents',
        'For backend non-trivial work, route pre-implementation analysis to `service-template` and `tdd-test`.',
        'Delegation: skipped user-opt-out'
    )) {
        if ($intakePlannerText -notmatch [regex]::Escape($requiredText)) {
            throw "Intake planner must detect agent-first routing: missing '$requiredText'."
        }
    }

    $implementationCoordinator = Join-Path $harnessRoot ".codex\agents\08-implementation-coordinator.toml"
    $implementationCoordinatorText = Get-Content -LiteralPath $implementationCoordinator -Raw
    foreach ($requiredText in @(
        'Main thread is the orchestrator, not the default implementer, for non-trivial work when task-agents is active.',
        'Agent-first means planning, implementation, review, and verification should be delegated to discovered repo-local agents whenever the task is non-trivial and subagent capability is available.',
        'Direct main-thread edits are allowed only for small fixes, integration of agent output, or non-overlapping unblock work.',
        'Agent-first handoff is the default for non-trivial dotnet-harness work. The user does not need to explicitly request subagent handoff.',
        'Each subagent output must be treated as the input contract for the next stage.',
        'Require actual subagent tool calls such as `spawn_agent`',
        'main-thread role-play does not count',
        'Require `Delegation: used` evidence',
        'tool-call receipt',
        'For non-trivial work, stop before implementation',
        'Do not report `Agent execution fallback: unavailable` while `spawn_agent`',
        'Reject plans that only read TOML files',
        'A delegation plan is not delegation evidence.',
        'Delegation: skipped coupled',
        'While subagents are running, do not duplicate their implementation scope in the main thread.',
        'Delegation: skipped user-opt-out',
        'prior output contracts',
        'delegation evidence'
    )) {
        if ($implementationCoordinatorText -notmatch [regex]::Escape($requiredText)) {
            throw "Implementation coordinator must enforce actual subagent tool usage: missing '$requiredText'."
        }
    }

    $codeReviewer = Join-Path $harnessRoot ".codex\agents\09-code-reviewer.toml"
    $codeReviewerText = Get-Content -LiteralPath $codeReviewer -Raw
    foreach ($requiredText in @(
        '/feedback',
        'participate early',
        'review scope, success criteria, risk, and likely regression surfaces',
        'Return `Next` as actionable next-stage input, not completion proof.'
    )) {
        if ($codeReviewerText -notmatch [regex]::Escape($requiredText)) {
            throw "Code reviewer must support early feedback routing: missing '$requiredText'."
        }
    }

    $verificationRunnerText = Get-Content -LiteralPath (Join-Path $harnessRoot ".codex\agents\10-verification-runner.toml") -Raw
    foreach ($requiredText in @(
        'agents used or skipped',
        'whether agent results were reflected',
        'TaskResult: not requested; not created',
        'Report whether TaskResult was explicitly requested',
        'Git: not requested; git-operator not used',
        'TaskResult is created only when the user explicitly says `TaskResult`, `result report`, `HTML report`, `결과 HTML`, `작업 결과 파일`',
        'Report whether git was explicitly requested'
    )) {
        if ($verificationRunnerText -notmatch [regex]::Escape($requiredText)) {
            throw "Verification runner must enforce final reporting policy: missing '$requiredText'."
        }
    }

    $workflowGuardrailsText = Get-Content -LiteralPath (Join-Path $harnessRoot ".codex\agents\01-workflow-guardrails.toml") -Raw
    foreach ($requiredText in @(
        '@dotnet-harness',
        'agent-first handoff triggers',
        'direct-main opt-out wording',
        'safety, approval, validation, TaskResult, and git gates active'
    )) {
        if ($workflowGuardrailsText -notmatch [regex]::Escape($requiredText)) {
            throw "Workflow guardrails must classify automatic handoff policy: missing '$requiredText'."
        }
    }

    $gitOperatorText = Get-Content -LiteralPath (Join-Path $harnessRoot ".codex\agents\11-git-operator.toml") -Raw
    foreach ($requiredText in @(
        'Only operate on git state when the user explicitly asks for commit, push, PR, merge, reset, clean, branch, or worktree actions.'
    )) {
        if ($gitOperatorText -notmatch [regex]::Escape($requiredText)) {
            throw "Git operator must require explicit git request: missing '$requiredText'."
        }
    }

    $goalBoundaryAgent = Join-Path $harnessRoot ".codex\agents\02-goal-boundary.toml"
    $goalBoundaryText = Get-Content -LiteralPath $goalBoundaryAgent -Raw
    foreach ($requiredText in @(
        'After every user answer, restate the updated goal boundary',
        'After each answer, recalculate ambiguity for every active feature goal',
        'After each answer, verify goal alignment',
        'If the average remains above 8% or the answer shifts the target goal',
        'Socratic: satisfied',
        'Goal Alignment'
    )) {
        if ($goalBoundaryText -notmatch [regex]::Escape($requiredText)) {
            throw "Goal boundary agent must enforce Socratic reassessment loop: missing '$requiredText'."
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
