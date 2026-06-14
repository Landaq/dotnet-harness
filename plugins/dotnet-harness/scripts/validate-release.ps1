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
$harnessConfig = Join-Path $harnessRoot ".codex\harness-config.json"
$installScript = Join-Path $pluginRootPath "install.ps1"
$bootstrapScript = Join-Path $skillsRoot "project-structure-setup\scripts\bootstrap_project_structure.py"
$packageVersionsManifest = Join-Path $skillsRoot "project-structure-setup\references\package-versions.json"
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
        'In `standard` and `deep`, report ambiguity before/after Socratic clarification, average ambiguity, goal alignment, and next stage before handoff.',
        'In `deep`, also report phase contracts, input/output contracts, and handoff gates.',
        'Agent Execution Contract',
        'Clarify Before Delegating',
        'Delegation Evidence',
        'Compressed Agent Handoff',
        'Mandatory Socratic Checkpoint',
        'Subagent Utilization Floor',
        'Subagent delegation',
        'Delegation',
        'Task Agents must clarify before delegating. Actual subagent execution begins only after Socratic goal clarification is satisfied and runtime delegation permission is present.',
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
        'Delegation: skipped no-explicit-agent-request',
        'Delegation: skipped',
        'No-spawn decisions must include the exact reason.',
        'When task-agents is active, the main thread is a coordinator/reporter, not the default implementer.',
        'Subagents own staged analysis, implementation, review, and verification only after clarification passes and delegation permission is present.',
        'runtime delegation permission is present',
        'When task-agents is active, the main thread is a coordinator/reporter, not the default implementer.',
        'Subagents own staged analysis, implementation, review, and verification only after clarification passes and delegation permission is present.',
        'Each subagent output must be treated as the input contract for the next stage.',
        'Do not hand off to the next agent until previous agent output is explicit, bounded, and usable as the next input contract.',
        'Previous agent output is clear only when it includes: role, scope, `Findings`, `Changes`, `Risks`, `Verify`, `Next`, affected paths, and open questions or `none`.',
        'Each handoff prompt must start with `Prior result accepted:` plus short caveman summary of the previous agent result and any unresolved risks.',
        'TaskResult remains opt-in only.',
        'Direct main-thread edits are allowed for direct answers, trivial one-file fixes, user opt-out, host-policy no-spawn fallback',
        'If runtime policy requires explicit authorization, do not spawn actual subagents.',
        'Non-trivial work means multi-step, multi-file, architecture/workflow/plugin/harness change, backend/frontend behavior change, test strategy, review, verification, CI, release-sensitive, or unclear approval-boundary work.',
        'Main-thread direct work is allowed for a direct answer, status check, trivial one-file fix, explicit agent opt-out, or proven subagent tooling fallback.',
        'If the user says `에이전트 쓰지마`, `no agents`, or equivalent explicit opt-out, do not spawn subagents; report `Delegation: skipped user-opt-out` and continue main-thread direct.',
        'Strict Workflow Order',
        'Requirement Intake',
        'Socratic Clarification',
        'Ambiguity Recalculation',
        'Goal Boundary Confirmation',
        'Agent Route Planning',
        'Subagent Handoff',
        'Worker Implementation',
        'Review Agent',
        'Verification Agent',
        'Main Thread Final Summary',
        'Phase handoff contract',
        'Every phase must state `Phase`, `Agent`, `Purpose`, `Input Contract`, `Output Contract`, `Handoff Gate`, and `Next Phase`.',
        'Do not enter next phase until current phase output satisfies its `Output Contract` and `Handoff Gate`.',
        'Phase 7 Worker Partition',
        'Worker agents are `standard`/`deep` only; `lightweight` mode must not call `backend-worker`, `frontend-worker`, `test-worker`, or `docs-harness-worker`.',
        'Preferred workers: `backend-worker`, `frontend-worker`, `test-worker`, and `docs-harness-worker`.',
        'Run feature workers in parallel only when their write sets are disjoint',
        'Run feature workers serially when slices share files, contracts, migrations, package files, solution files, runtime state, release state, or unresolved decisions.',
        'Parallel: yes',
        'Parallel: no',
        '`Workers`: feature worker agents, feature slice ownership, parallel eligibility, and serial order when needed.',
        'Handoff Gate must include accepted prior result summary, unresolved risks, open questions or `none`, and whether the next phase may proceed.',
        'Handoff prompt must include `Phase`, `Agent`, `Purpose`, `Input Contract`, `Output Contract`, `Handoff Gate`, and `Next Phase`.',
        '`Phase`: numbered workflow phase and phase name.',
        '`Agent`: called agent name and role.',
        '`Purpose`: why this phase/agent exists.',
        '`Input Contract`: accepted prior result used as input.',
        '`Output Contract`: required result fields for next phase.',
        '`Handoff Gate`: pass/fail, unresolved risks, open questions or `none`, and next phase permission.',
        'Subagent output as next input',
        'For backend non-trivial work, spawn `service-template` and `tdd-test` as read-only specialists before implementation unless fallback, explicit opt-out, no explicit authorization under explicit-auth runtime policy, or a concrete skip condition applies.',
        '/feedback',
        'user explicitly opts out of agents',
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
        'must clarify before delegating',
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
        if (-not (Test-PolicyPattern $taskAgentsPolicy $requiredText)) {
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
            if (-not (Test-PolicyPattern $agentText $requiredText)) {
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
        'clarification-first',
        'Delegation Permission: not explicit',
        'For backend non-trivial work, route pre-implementation analysis to `service-template` and `tdd-test`.',
        'Delegation: skipped user-opt-out'
    )) {
        if (-not (Test-PolicyPattern $intakePlannerText $requiredText)) {
            throw "Intake planner must detect agent-first routing: missing '$requiredText'."
        }
    }

    $implementationCoordinator = Join-Path $harnessRoot ".codex\agents\08-implementation-coordinator.toml"
    $implementationCoordinatorText = Get-Content -LiteralPath $implementationCoordinator -Raw
    foreach ($requiredText in @(
        'Select workflow mode first: `lightweight` for trivial/small work, `standard` for non-trivial work, and `deep` for explicit deep, release, scaffold, architecture, or high-risk work.',
        'In `lightweight`, keep phase contracts internal, ask at most one clarification question, do not call workers, and report only concise Socratic/change/verification/delegation/git/TaskResult status.',
        'In `standard`, start with Requirement Intake, Socratic Clarification, Ambiguity Recalculation, and Goal Boundary Confirmation',
        'In `deep`, expose full Socratic status, phase contracts, handoff gates, review, and verification evidence.',
        'Main thread is the coordinator/reporter for non-trivial work when task-agents is active.',
        'Task Agents must clarify before delegating. Actual subagent execution begins only after Socratic goal clarification is satisfied and runtime delegation permission is present.',
        'Direct main-thread edits are allowed only for direct answers, trivial one-file fixes, user opt-out, host-policy no-spawn fallback',
        'Treat `$dotnet-harness`, `task-agents`, `/feedback`, `에이전트`, `subagent`, `서브에이전트`, `에이전트에게 맡겨`, or `작업을 에이전트들이 수행` as explicit authorization',
        'Delegation: skipped no-explicit-agent-request',
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
        'Worker agents are `standard`/`deep` only; never assign `backend-worker`, `frontend-worker`, `test-worker`, or `docs-harness-worker` in `lightweight`.',
        'Preferred workers are `backend-worker`, `frontend-worker`, `test-worker`, and `docs-harness-worker`.',
        'Run workers in parallel only when write sets are disjoint, public contracts are stable, migrations are absent, package/solution files are not shared, and validation can run independently.',
        'Run workers serially when slices share files, contracts, migrations, package files, solution files, runtime state, release state, or unresolved decisions.',
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
        'For `standard` and `deep`, report ambiguity before/after Socratic clarification, average ambiguity, goal alignment, and next stage before handoff.'
    )) {
        if (-not (Test-PolicyPattern $implementationCoordinatorText $requiredText)) {
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
            if (-not (Test-PolicyPattern $workerText $requiredText)) {
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
        if (-not (Test-PolicyPattern $codeReviewerText $requiredText)) {
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
        if (-not (Test-PolicyPattern $verificationRunnerText $requiredText)) {
            throw "Verification runner must enforce final reporting policy: missing '$requiredText'."
        }
    }

    $workflowGuardrailsText = Get-Content -LiteralPath (Join-Path $harnessRoot ".codex\agents\01-workflow-guardrails.toml") -Raw
    foreach ($requiredText in @(
        '@dotnet-harness',
        'Delegation Permission: not explicit',
        'direct-main opt-out wording',
        'safety, approval, validation, TaskResult, and git gates active'
    )) {
        if (-not (Test-PolicyPattern $workflowGuardrailsText $requiredText)) {
            throw "Workflow guardrails must classify automatic handoff policy: missing '$requiredText'."
        }
    }

    $gitOperatorText = Get-Content -LiteralPath (Join-Path $harnessRoot ".codex\agents\11-git-operator.toml") -Raw
    foreach ($requiredText in @(
        'Only operate on git state when the user explicitly asks for commit, push, PR, merge, reset, clean, branch, or worktree actions.'
    )) {
        if (-not (Test-PolicyPattern $gitOperatorText $requiredText)) {
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
        if (-not (Test-PolicyPattern $goalBoundaryText $requiredText)) {
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

    if (-not (Test-Path -LiteralPath $harnessConfig)) {
        throw "Missing harness config defaults: $harnessConfig"
    }
    $harnessConfigText = Get-Content -LiteralPath $harnessConfig -Raw
    foreach ($requiredText in @("defaultLibrary", "biLibrary", "devExpressVersion")) {
        if (-not (Test-PolicyPattern $harnessConfigText $requiredText)) {
            throw "Harness config defaults missing required UI key: '$requiredText'."
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
        if (-not (Test-PolicyPattern $ensureCaveman $requiredText)) {
            throw "Caveman optional skill helper missing required behavior: '$requiredText'."
        }
    }

    foreach ($scriptPath in @($installScript, $bootstrapScript, $upgradeScript)) {
        $scriptText = Get-Content -LiteralPath $scriptPath -Raw
        if ($scriptText -notmatch "InstallOptionalSkills|install-optional-skills") {
            throw "Setup/upgrade path must expose optional skill installation: $scriptPath"
        }
    }

    $upgradeText = Get-Content -LiteralPath $upgradeScript -Raw
    foreach ($requiredText in @(".codex\harness-config.json", "[create]", "[preview] create")) {
        if (-not (Test-PolicyPattern $upgradeText $requiredText)) {
            throw "Upgrade path must create missing harness config without overwriting: '$requiredText'."
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
        if (-not (Test-PolicyPattern $writeTaskResultText $requiredText)) {
            throw "TaskResult wrapper missing retention option: '$requiredText'."
        }
    }
    $writeTaskResultPythonText = Get-Content -LiteralPath $writeTaskResultPython -Raw
    foreach ($requiredText in @('archive_dir', 'no_prune', 'old.replace(target)', '--no-prune')) {
        if (-not (Test-PolicyPattern $writeTaskResultPythonText $requiredText)) {
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
        if (-not (Test-PolicyPattern $releaseHelperText $requiredText)) {
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

Invoke-ValidationStep "package version manifest" {
    if (-not (Test-Path -LiteralPath $packageVersionsManifest)) {
        throw "Missing package version manifest: $packageVersionsManifest"
    }

    $manifest = Get-Content -LiteralPath $packageVersionsManifest -Raw | ConvertFrom-Json
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

    $bootstrapText = Get-Content -LiteralPath $bootstrapScript -Raw
    foreach ($requiredText in @("package-versions.json", "_package_versions_props", "json.load")) {
        if (-not (Test-PolicyPattern $bootstrapText $requiredText)) {
            throw "bootstrap must generate Directory.Packages.props from package-versions.json: missing '$requiredText'."
        }
    }
}

function Invoke-CheckedCommand {
    param(
        [string]$Name,
        [string]$WorkingDirectory,
        [string[]]$Command
    )

    Write-Host "[smoke] $Name"
    $executable = $Command[0]
    $arguments = @($Command | Select-Object -Skip 1)
    & $executable @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed in $WorkingDirectory with exit code $LASTEXITCODE."
    }
}

function Invoke-ScaffoldBuildSmoke {
    param(
        [string]$Name,
        [string]$ProjectName,
        [string]$ServiceName
    )

    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("dotnet-harness-smoke-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    try {
        $installArgs = @("-NoProfile", "-File", $installScript, "-Root", $root, "-ProjectName", $ProjectName)
        if ($ServiceName) {
            $installArgs += @("-ServiceName", $ServiceName)
        }
        else {
            $installArgs += "-NoService"
        }
        & pwsh @installArgs
        if ($LASTEXITCODE -ne 0) {
            throw "$Name scaffold install failed."
        }

        $solution = Join-Path $root "$ProjectName.slnx"
        if (-not (Test-Path -LiteralPath $solution)) {
            throw "$Name did not create expected solution: $solution"
        }

        Push-Location $root
        try {
            Invoke-CheckedCommand -Name "$Name restore" -WorkingDirectory $root -Command @("dotnet", "restore", "$ProjectName.slnx")
            Invoke-CheckedCommand -Name "$Name build" -WorkingDirectory $root -Command @("dotnet", "build", "$ProjectName.slnx", "--no-restore")
            Invoke-CheckedCommand -Name "$Name test" -WorkingDirectory $root -Command @("dotnet", "test", "$ProjectName.slnx", "--no-build")
        }
        finally {
            Pop-Location
        }
    }
    finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Invoke-ValidationStep "scaffold smoke" {
    Invoke-ScaffoldBuildSmoke -Name "no-service scaffold" -ProjectName "SmokeNoService"
    Invoke-ScaffoldBuildSmoke -Name "with-service scaffold" -ProjectName "SmokeWithService" -ServiceName "Auth"

    $harnessOnlyRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("dotnet-harness-harnessonly-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $harnessOnlyRoot | Out-Null
    try {
        & pwsh -NoProfile -File $installScript -Root $harnessOnlyRoot -ProjectName "HarnessOnlySmoke" -HarnessOnly
        if ($LASTEXITCODE -ne 0) {
            throw "harness-only install failed."
        }
        if (Test-Path -LiteralPath (Join-Path $harnessOnlyRoot "src")) {
            throw "harness-only install must not create src."
        }
        if (Test-Path -LiteralPath (Join-Path $harnessOnlyRoot "test")) {
            throw "harness-only install must not create test."
        }
        foreach ($required in @("AGENTS.md", ".codex\agents", ".codex\scripts")) {
            if (-not (Test-Path -LiteralPath (Join-Path $harnessOnlyRoot $required))) {
                throw "harness-only install missing $required."
            }
        }
    }
    finally {
        Remove-Item -LiteralPath $harnessOnlyRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    $upgradeRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("dotnet-harness-upgrade-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path (Join-Path $upgradeRoot ".codex\agents") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $upgradeRoot ".codex\skills\legacy") | Out-Null
    Set-Content -LiteralPath (Join-Path $upgradeRoot ".codex\agents\legacy.toml") -Value 'name = "legacy"' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $upgradeRoot ".codex\skills\legacy\SKILL.md") -Value '# Legacy' -Encoding UTF8
    try {
        & pwsh -NoProfile -File $upgradeScript -TargetRoot $upgradeRoot -SourceRoot $harnessRoot
        if ($LASTEXITCODE -ne 0) {
            throw "upgrade preview failed."
        }
        & pwsh -NoProfile -File $upgradeScript -TargetRoot $upgradeRoot -SourceRoot $harnessRoot -Apply
        if ($LASTEXITCODE -ne 0) {
            throw "upgrade apply failed."
        }
        if (Test-Path -LiteralPath (Join-Path $upgradeRoot ".codex\skills")) {
            throw "upgrade apply must remove active .codex\skills."
        }
        foreach ($required in @(".gitignore", ".gitattributes", ".codex\harness-config.json", ".codex\agents", ".codex\scripts")) {
            if (-not (Test-Path -LiteralPath (Join-Path $upgradeRoot $required))) {
                throw "upgrade apply missing $required."
            }
        }
    }
    finally {
        Remove-Item -LiteralPath $upgradeRoot -Recurse -Force -ErrorAction SilentlyContinue
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
