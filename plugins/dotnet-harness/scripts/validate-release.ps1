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
$releaseHelperScript = Join-Path $pluginRootPath "scripts\release-helper.ps1"

$policyParseScript = @'
import pathlib
import sys
import tomllib

path = pathlib.Path(sys.argv[1])
expected_modes = set(sys.argv[2].split(","))
with path.open("rb") as handle:
    data = tomllib.load(handle)

policy = data.get("policy")
if not isinstance(policy, dict):
    raise SystemExit(f"{path.name} missing [policy]")

for key in ("required_capabilities", "required_output_keys", "workflow_modes"):
    value = policy.get(key)
    if not isinstance(value, list) or not value or not all(isinstance(item, str) and item.strip() for item in value):
        raise SystemExit(f"{path.name} invalid [policy].{key}")

actual_modes = set(policy["workflow_modes"])
if actual_modes != expected_modes:
    raise SystemExit(f"{path.name} workflow_modes expected {sorted(expected_modes)} got {sorted(actual_modes)}")
'@

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

Invoke-ValidationStep "version consistency" {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $manifestVersion = [string]$manifest.version
    $versionText = Get-Content -LiteralPath (Join-Path $pluginRootPath "VERSION.md") -Raw
    $versionMatch = [regex]::Match($versionText, 'Current version:\s*`(?<version>[^`]+)`')
    if (-not $versionMatch.Success) {
        throw "VERSION.md must contain a Current version line."
    }
    $versionFileVersion = $versionMatch.Groups["version"].Value
    if ($manifestVersion -ne $versionFileVersion) {
        throw "plugin.json version '$manifestVersion' does not match VERSION.md '$versionFileVersion'."
    }
    if (-not (Test-Path -LiteralPath $releaseHelperScript)) {
        throw "Missing release helper: $releaseHelperScript"
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
    $taskAgentsReferences = Join-Path (Split-Path -Path $taskAgentsSkill -Parent) "references"
    if (-not (Test-Path -LiteralPath $taskAgentsReferences)) {
        throw "Task Agents references directory is required after splitting policy docs."
    }

    $requiredTaskAgentReferences = @(
        "workflow-modes.md",
        "phase-contracts.md",
        "delegation-policy.md",
        "worker-policy.md",
        "domain-policies.md",
        "task-result-and-git.md"
    )
    foreach ($referenceName in $requiredTaskAgentReferences) {
        $referencePath = Join-Path $taskAgentsReferences $referenceName
        if (-not (Test-Path -LiteralPath $referencePath)) {
            throw "Missing Task Agents reference: $referencePath"
        }
    }

    $taskAgentsPolicy = $taskAgents
    foreach ($referenceFile in Get-ChildItem -LiteralPath $taskAgentsReferences -File -Filter "*.md" | Sort-Object Name) {
        $taskAgentsPolicy += "`n" + (Get-Content -LiteralPath $referenceFile.FullName -Raw)
    }

    if ($taskAgents -match "Before final response,\s*write the Task Result") {
        throw "TaskResult artifact must be opt-in, not mandatory."
    }

    $currentDocs = @(
        Join-Path $pluginRootPath "README.md"
        Join-Path $skillsRoot "project-structure-setup\SKILL.md"
    )
    $staleDocRefs = $currentDocs |
        Where-Object { Test-Path -LiteralPath $_ } |
        Select-String -Pattern "repo-local skills|docs/wkTask|python scripts/bootstrap_project_structure.py" -ErrorAction SilentlyContinue
    if ($staleDocRefs) {
        throw "Current plugin docs contain stale repo-local skill, default plan artifact, or direct Python CLI guidance."
    }

    foreach ($requiredText in @(
        'Workflow Modes',
        'Select one workflow mode before routing:',
        '`lightweight`: default for trivial or small tasks.',
        '`standard`: default for non-trivial work.',
        '`deep`: use when the user explicitly asks for deep review/planning',
        'Trivial or small work -> `lightweight`.',
        'Non-trivial work -> `standard`.',
        'Explicit deep/release/scaffold/architecture/high-risk work -> `deep`.',
        'In `lightweight` and `standard`, ambiguity percentage is an internal routing signal.',
        'In `deep`, report ambiguity percentage, phase contracts, input/output contracts, and handoff gates.',
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
        'Do not hand off to the next agent until previous agent output is explicit, bounded, and usable as the next input contract.',
        'Previous agent output is clear only when it includes: role, scope, `Findings`, `Changes`, `Risks`, `Verify`, `Next`, affected paths, and open questions or `none`.',
        'Each handoff prompt must start with `Prior result accepted:` plus short caveman summary of the previous agent result and any unresolved risks.',
        'TaskResult remains opt-in only.',
        'Direct main-thread edits are allowed only for small fixes, integration of agent output, or non-overlapping unblock work.',
        'If the user explicitly invokes `@dotnet-harness` for non-trivial work, treat the request as task-agents active and agent-first unless the user explicitly opts out of agents.',
        'Non-trivial work means multi-step, multi-file, architecture/workflow/plugin/harness change, backend/frontend behavior change, test strategy, review, verification, CI, release-sensitive, or unclear approval-boundary work.',
        'Main-thread direct work is allowed for a direct answer, status check, trivial one-file fix, or explicit agent opt-out.',
        'If the user says `에이전트 쓰지마`, `no agents`, or equivalent explicit opt-out, do not spawn subagents; report `Delegation: skipped user-opt-out` and continue main-thread direct.',
        'Strict staged handoff order',
        'Phase 0 - Workflow Guardrails',
        'Phase 1 - Goal Boundary',
        'Phase 2 - Intake Planning',
        'Phase 3 - Implementation Coordination',
        'Phase 4 - Specialist Analysis',
        'Phase 5 - Bounded Implementation',
        'Phase 6 - Review',
        'Phase 7 - Verification',
        'Phase 8 - Git Operation',
        'Phase handoff contract',
        'Every phase must state `Phase`, `Agent`, `Purpose`, `Input Contract`, `Output Contract`, `Handoff Gate`, and `Next Phase`.',
        'Do not enter next phase until current phase output satisfies its `Output Contract` and `Handoff Gate`.',
        'Phase 5 worker partition',
        'Phase 5 worker agents are `standard`/`deep` only; `lightweight` mode must not call `backend-worker`, `frontend-worker`, `test-worker`, or `docs-harness-worker`.',
        'Preferred workers: `backend-worker`, `frontend-worker`, `test-worker`, and `docs-harness-worker`.',
        'Run feature workers in parallel only when their write sets are disjoint, public contracts are stable, migrations are absent, package/solution files are not shared, and validation can run independently.',
        'Run feature workers serially when slices share files, contracts, migrations, package files, solution files, runtime state, release state, or unresolved decisions.',
        'Parallel: yes',
        'Parallel: no',
        'Workers`: feature worker agents, feature slice ownership, parallel eligibility, and serial order when needed.',
        'Handoff Gate must include accepted prior result summary, unresolved risks, open questions or `none`, and whether the next phase may proceed.',
        'Handoff prompt must include `Phase`, `Agent`, `Purpose`, `Input Contract`, `Output Contract`, `Handoff Gate`, and `Next Phase`.',
        '`Phase`: numbered workflow phase and phase name.',
        '`Agent`: called agent name and role.',
        '`Purpose`: why this phase/agent exists.',
        '`Input Contract`: accepted prior result used as input.',
        '`Output Contract`: required result fields for next phase.',
        '`Handoff Gate`: pass/fail, unresolved risks, open questions or `none`, and next phase permission.',
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
        'Move older result files into `docs/TaskResult/archive` instead of deleting them.',
        'Use `-NoPrune` only when the user explicitly wants to keep every result in the active directory.',
        'Limit pre-implementation read-only subagents to three unless the user explicitly approves more.',
        'Delegate implementation only when write sets are disjoint and requirements are settled.',
        'utilization floor satisfied',
        'Socratic',
        'Ask at least one Korean Socratic question',
        'Print `Socratic: skipped`',
        'Socratic: satisfied',
        'target average ambiguity `<= 8%`',
        'Ambiguity scoring rubric:',
        'Score ambiguity from concrete unresolved blockers, not model confidence.',
        'Business goal:',
        'Input/output specification:',
        'Persistence/data/runtime rules:',
        'Validation evidence:',
        'Approval/release/git boundary:',
        'do not lower the score only because the model feels confident.',
        'Recalculate ambiguity percentage for each active feature goal and the average ambiguity after every answer.',
        'Check goal alignment after every answer',
        'Before moving to any next work stage, explicitly tell the user the updated feature ambiguity %, average ambiguity %, goal alignment result, and next stage.',
        'Continue this answer -> reassess -> ask loop until average ambiguity is `<= 8%`',
        'After every user answer, restate the updated goal boundary, recalculate each feature ambiguity %, recalculate average ambiguity %, and check whether the answer still aligns with the active goal.',
        'Before moving to the next stage, explicitly show the user the recalculated ambiguity and goal alignment result.',
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
        'Next:',
        'Mode-specific final reporting:',
        '`lightweight`: include `Agents Used`, `Agents Skipped`, `Main Thread Work`, `Review/Verification Evidence`, `Files Changed`, `Git`, and `TaskResult` only.',
        '`standard`: include concise phase summary, selected agents, skipped agents, worker eligibility, verification evidence, changed files, git status, and TaskResult status.',
        '`deep`: include full phase/input/output/handoff-gate reporting, Socratic status, worker partition, review findings, verification evidence, changed files, git status, and TaskResult status.',
        'Before enforcing UI library rules, inspect `.codex/harness-config.json` when present.',
        'If `.codex/harness-config.json` declares `ui.defaultLibrary`, `ui.biLibrary`, or `ui.devExpressVersion`, follow that project config and report the override.',
        'Supported default-library examples include `MudBlazor`, `FluentUI`, `BlazorBuiltIn`, and `TailwindOnly`'
    )) {
        if ($taskAgentsPolicy -notmatch [regex]::Escape($requiredText)) {
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
        Join-Path $harnessRoot ".codex\agents\12-backend-worker.toml"
        Join-Path $harnessRoot ".codex\agents\13-frontend-worker.toml"
        Join-Path $harnessRoot ".codex\agents\14-test-worker.toml"
        Join-Path $harnessRoot ".codex\agents\15-docs-harness-worker.toml"
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
        'Select workflow mode first: `lightweight` for trivial/small work, `standard` for non-trivial work, and `deep` for explicit deep, release, scaffold, architecture, or high-risk work.',
        'In `lightweight`, keep phase contracts internal, ask at most one clarification question, do not call Phase 5 workers, and report only concise change/verification/delegation/git/TaskResult status.',
        'In `standard`, use Phase 0-8 with concise transitions, call only needed agents, and allow Phase 5 workers only when requirements are settled.',
        'In `deep`, expose full Socratic status, phase contracts, handoff gates, review, and verification evidence.',
        'Main thread is the orchestrator, not the default implementer, for non-trivial work when task-agents is active.',
        'Agent-first means planning, implementation, review, and verification should be delegated to discovered repo-local agents whenever the task is non-trivial and subagent capability is available.',
        'Direct main-thread edits are allowed only for small fixes, integration of agent output, or non-overlapping unblock work.',
        'Agent-first handoff is the default for non-trivial dotnet-harness work. The user does not need to explicitly request subagent handoff.',
        'Each subagent output must be treated as the input contract for the next stage.',
        'Phase 0 Workflow Guardrails',
        'Phase 1 Goal Boundary',
        'Phase 2 Intake Planning',
        'Phase 3 Implementation Coordination',
        'Phase 4 Specialist Analysis',
        'Phase 5 Bounded Implementation',
        'Phase 6 Review',
        'Phase 7 Verification',
        'Phase 8 Git Operation',
        'For every phase, state `Phase`, `Agent`, `Purpose`, `Input Contract`, `Output Contract`, `Handoff Gate`, and `Next Phase`.',
        'Do not start a next phase until the current phase handoff gate passes.',
        'Phase 5 workers are `standard`/`deep` only; never assign `backend-worker`, `frontend-worker`, `test-worker`, or `docs-harness-worker` in `lightweight`.',
        'Preferred Phase 5 workers are `backend-worker`, `frontend-worker`, `test-worker`, and `docs-harness-worker`.',
        'Run Phase 5 workers in parallel only when write sets are disjoint, public contracts are stable, migrations are absent, package/solution files are not shared, and validation can run independently.',
        'Run Phase 5 workers serially when slices share files, contracts, migrations, package files, solution files, runtime state, release state, or unresolved decisions.',
        'Parallel: yes',
        'Parallel: no',
        'worker assignments',
        'Do not hand off to the next agent until previous agent output is explicit, bounded, and usable as the next input contract.',
        'Accept previous agent output only when it includes role, scope, `Findings`, `Changes`, `Risks`, `Verify`, `Next`, affected paths, and open questions or `none`.',
        'Prior result accepted:',
        'explicit phases',
        'phase agents',
        'phase purposes',
        'input/output contracts',
        'handoff gates',
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
        'delegation evidence',
        'For `lightweight` and `standard`, keep ambiguity percentage internal unless a gate blocks progress; report remaining uncertainty in natural language.'
    )) {
        if ($implementationCoordinatorText -notmatch [regex]::Escape($requiredText)) {
            throw "Implementation coordinator must enforce actual subagent tool usage: missing '$requiredText'."
        }
    }

    & python -c $policyParseScript $implementationCoordinator "lightweight,standard,deep"
    if ($LASTEXITCODE -ne 0) {
        throw "Implementation coordinator must expose structured workflow mode policy metadata."
    }

    $workerPolicies = @{
        "12-backend-worker.toml" = "standard,deep"
        "13-frontend-worker.toml" = "standard,deep"
        "14-test-worker.toml" = "standard,deep"
        "15-docs-harness-worker.toml" = "standard,deep"
    }
    foreach ($workerName in $workerPolicies.Keys) {
        $workerPath = Join-Path $harnessRoot ".codex\agents\$workerName"
        $workerText = Get-Content -LiteralPath $workerPath -Raw
        foreach ($requiredText in @(
            'Require workflow mode input; refuse `lightweight` and run only in `standard` or `deep`.',
            'Require allowed paths, forbidden paths, parallel eligibility, expected changed files, validation evidence, and stop condition.'
        )) {
            if ($workerText -notmatch [regex]::Escape($requiredText)) {
                throw "Worker agent must enforce workflow mode gate: $workerName missing '$requiredText'."
            }
        }
        & python -c $policyParseScript $workerPath $workerPolicies[$workerName]
        if ($LASTEXITCODE -ne 0) {
            throw "Worker agent must expose structured policy metadata: $workerName"
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
        'Before moving to any next work stage, explicitly tell the user the updated feature ambiguity %, average ambiguity %, goal alignment result, and next stage.',
        'After each answer, explicitly report the recalculated ambiguity and goal alignment to the user before handoff or any next stage.',
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
        'Refusing to install caveman outside the repo without -AllowUserSkillInstall',
        '-AllowUserSkillInstall',
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

    $writeTaskResultScript = Join-Path $harnessRoot ".codex\scripts\write-task-result.ps1"
    $writeTaskResultPython = Join-Path $harnessRoot ".codex\scripts\write_task_result.py"
    foreach ($requiredPath in @($writeTaskResultScript, $writeTaskResultPython)) {
        if (-not (Test-Path -LiteralPath $requiredPath)) {
            throw "Missing TaskResult helper: $requiredPath"
        }
    }
    $writeTaskResultText = Get-Content -LiteralPath $writeTaskResultScript -Raw
    foreach ($requiredText in @('ArchiveDir', 'NoPrune', '--archive-dir', '--no-prune')) {
        if ($writeTaskResultText -notmatch [regex]::Escape($requiredText)) {
            throw "TaskResult wrapper missing retention option: '$requiredText'."
        }
    }
    $writeTaskResultPythonText = Get-Content -LiteralPath $writeTaskResultPython -Raw
    foreach ($requiredText in @('archive_dir', 'no_prune', 'old.replace(target)', '--no-prune')) {
        if ($writeTaskResultPythonText -notmatch [regex]::Escape($requiredText)) {
            throw "TaskResult helper missing archive retention behavior: '$requiredText'."
        }
    }
    if ($writeTaskResultPythonText -match '\.unlink\(') {
        throw "TaskResult helper must not delete old result files with unlink()."
    }

    $releaseHelperText = Get-Content -LiteralPath $releaseHelperScript -Raw
    foreach ($requiredText in @(
        'Version must be SemVer core format',
        'plugin.json',
        'VERSION.md',
        '-Apply'
    )) {
        if ($releaseHelperText -notmatch [regex]::Escape($requiredText)) {
            throw "Release helper missing required behavior: '$requiredText'."
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
