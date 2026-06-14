param(
    [string]$RepoRoot = (Get-Location).Path
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

function Require-Path {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        Add-Failure "Missing path: $Path"
    }
}

$agentsDir = Join-Path $RepoRoot ".codex\agents"
$skillsDir = Join-Path $RepoRoot ".codex\skills"
$rootAgents = Join-Path $RepoRoot "AGENTS.md"
$harnessConfig = Join-Path $RepoRoot ".codex\harness-config.json"

Require-Path $agentsDir
Require-Path $rootAgents
Require-Path $harnessConfig
$ensureCavemanScript = Join-Path $RepoRoot ".codex\scripts\ensure-caveman-skill.ps1"
$writeTaskResultScript = Join-Path $RepoRoot ".codex\scripts\write-task-result.ps1"
$writeTaskResultPython = Join-Path $RepoRoot ".codex\scripts\write_task_result.py"
Require-Path $ensureCavemanScript
Require-Path $writeTaskResultScript
Require-Path $writeTaskResultPython

if (Test-Path -LiteralPath $skillsDir) {
    Add-Failure "Repo-local .codex\skills should not exist. Use dotnet-harness:* plugin skills instead: $skillsDir"
}

$requiredAgents = @(
    "01-workflow-guardrails.toml",
    "02-goal-boundary.toml",
    "03-service-template.toml",
    "04-frontend-ui.toml",
    "05-tdd-test.toml",
    "06-reference-auditor.toml",
    "07-intake-planner.toml",
    "08-implementation-coordinator.toml",
    "09-code-reviewer.toml",
    "10-verification-runner.toml",
    "11-git-operator.toml",
    "12-backend-worker.toml",
    "13-frontend-worker.toml",
    "14-test-worker.toml",
    "15-docs-harness-worker.toml",
    "16-backend-reviewer.toml",
    "17-frontend-reviewer.toml",
    "18-test-reviewer.toml",
    "19-docs-harness-reviewer.toml",
    "20-feature-slicer.toml",
    "21-docs-harness-specialist.toml"
)

foreach ($agent in $requiredAgents) {
    Require-Path (Join-Path $agentsDir $agent)
}

$requiredKeys = @(
    "name",
    "description",
    "developer_instructions",
    "model_reasoning_effort",
    "sandbox_mode"
)

$tomlParseScript = @'
import pathlib
import sys
import tomllib

path = pathlib.Path(sys.argv[1])
required = {
    "name",
    "description",
    "developer_instructions",
    "model_reasoning_effort",
    "sandbox_mode",
}

with path.open("rb") as handle:
    data = tomllib.load(handle)

missing = sorted(required - data.keys())
if missing:
    raise SystemExit(f"{path.name} missing keys: {', '.join(missing)}")

for key in required:
    value = data[key]
    if not isinstance(value, str) or not value.strip():
        raise SystemExit(f"{path.name} invalid non-empty string key: {key}")
'@

if (Test-Path -LiteralPath $agentsDir) {
    $agentNames = @{}
    foreach ($agentFile in Get-ChildItem -LiteralPath $agentsDir -Filter "*.toml" -File) {
        & python -c $tomlParseScript $agentFile.FullName
        if ($LASTEXITCODE -ne 0) {
            Add-Failure "$($agentFile.Name) failed Python tomllib parse"
        }

        $content = Get-Content -LiteralPath $agentFile.FullName -Raw
        if ($content -match "(?m)^\s*\[policy\]\s*$") {
            Add-Failure "$($agentFile.Name) contains unsupported [policy] table. Keep policy as developer_instructions text."
        }

        foreach ($key in $requiredKeys) {
            if ($content -notmatch "(?m)^$key\s*=\s*.+") {
                Add-Failure "$($agentFile.Name) missing key: $key"
            }
        }

        foreach ($key in @("name", "description", "model_reasoning_effort", "sandbox_mode")) {
            $match = [regex]::Match($content, "(?m)^$key\s*=\s*`"([^`"]+)`"\s*$")
            if (-not $match.Success) {
                Add-Failure "$($agentFile.Name) invalid scalar string key: $key"
            }
            elseif ($key -eq "name") {
                $agentName = $match.Groups[1].Value
                if ($agentNames.ContainsKey($agentName)) {
                    Add-Failure "Duplicate active agent name '$agentName': $($agentNames[$agentName]) and $($agentFile.Name)"
                }
                else {
                    $agentNames[$agentName] = $agentFile.Name
                }
            }
        }

        if ($content -notmatch '(?ms)^developer_instructions\s*=\s*""".+?"""') {
            Add-Failure "$($agentFile.Name) invalid developer_instructions multiline block"
        }

        $tripleQuoteCount = ([regex]::Matches($content, '"""')).Count
        if (($tripleQuoteCount % 2) -ne 0) {
            Add-Failure "$($agentFile.Name) unbalanced triple quotes"
        }

        foreach ($requiredAgentConfig in @(
            '[mcp_servers.context7]',
            'command = "npx"',
            'args = ["-y", "@upstash/context7-mcp"]',
            '[mcp_servers.openaiDeveloperDocs]',
            'url = "https://developers.openai.com/mcp"',
            '[[skills.config]]',
            'path = "~/.agents/skills/caveman/SKILL.md"',
            'enabled = true',
            'mode = "full"',
            'usage = "internal-subagent-handoff"'
        )) {
            if ($content -notmatch [regex]::Escape($requiredAgentConfig)) {
                Add-Failure "$($agentFile.Name) missing fixed agent config: $requiredAgentConfig"
            }
        }
    }

    $goalBoundaryAgent = Join-Path $agentsDir "02-goal-boundary.toml"
    $implementationCoordinator = Join-Path $agentsDir "08-implementation-coordinator.toml"
    $intakePlanner = Join-Path $agentsDir "07-intake-planner.toml"
    $codeReviewer = Join-Path $agentsDir "09-code-reviewer.toml"
    $verificationRunner = Join-Path $agentsDir "10-verification-runner.toml"

    if (Test-Path -LiteralPath $goalBoundaryAgent) {
        $goalBoundaryText = Get-Content -LiteralPath $goalBoundaryAgent -Raw
        foreach ($requiredText in @(
            "After every user answer, restate the updated goal boundary",
            "After each answer, recalculate ambiguity for every active feature goal",
            "After each answer, verify goal alignment",
            "Before moving to any next work stage, explicitly tell the user the updated feature ambiguity %, average ambiguity %, goal alignment result, and next stage.",
            "After each answer, explicitly report the recalculated ambiguity and goal alignment to the user before handoff or any next stage.",
            "If the average remains above 8% or the answer shifts the target goal",
            "Socratic: satisfied",
            "Goal Alignment"
        )) {
            if (-not (Test-PolicyPattern $goalBoundaryText $requiredText)) {
                Add-Failure "goal-boundary missing Socratic reassessment policy: $requiredText"
            }
        }
    }

    if (Test-Path -LiteralPath $implementationCoordinator) {
        $implementationText = Get-Content -LiteralPath $implementationCoordinator -Raw
        foreach ($requiredText in @(
            'Select workflow mode first: `lightweight` for trivial/small work, `standard` for non-trivial work, and `deep` for explicit deep, release, scaffold, architecture, or high-risk work.',
            'In `lightweight`, keep phase contracts internal, ask at most one clarification question, do not call workers, and report only concise Socratic/change/verification/delegation/git/TaskResult status.',
            'In `standard`, start with Requirement Intake, Socratic Clarification, Ambiguity Recalculation, and Goal Boundary Confirmation',
            'In `deep`, expose full Socratic status, phase contracts, handoff gates, review, and verification evidence.',
            'Main thread is the coordinator/reporter for non-trivial work when task-agents is active.',
            'Subagents own staged analysis, implementation, review, and verification only after clarification passes and delegation permission is present.',
            'Direct main-thread edits are allowed only for direct answers, trivial one-file fixes, user opt-out, host-policy no-spawn fallback',
            'Task Agents must clarify before delegating. Actual subagent execution begins only after Socratic goal clarification is satisfied and runtime delegation permission is present.',
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
            'Route non-trivial multi-area work through `feature-slicer`',
            'Use feature-scoped read-only specialists',
            'Preferred feature-scoped specialists are `service-template`, `frontend-ui`, `tdd-test`, `reference-auditor`, and `docs-harness-specialist`.',
            'Route post-implementation checks to the smallest relevant reviewer set',
            'Split review work by feature slice.',
            'Prefer parallel read-only review when reviewers inspect disjoint feature slices or distinct perspectives over the same completed slice.',
            'Run workers in parallel only when write sets are disjoint, public contracts are stable, migrations are absent, package/solution files are not shared, and validation can run independently.',
            'Run workers serially when slices share files, contracts, migrations, package files, solution files, runtime state, release state, or unresolved decisions.',
            'Parallel: yes',
            'Parallel: no',
            'worker assignments',
            'feature-slicer output',
            'specialist assignments',
            'reviewer assignments by feature slice',
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
            if (-not (Test-PolicyPattern $implementationText $requiredText)) {
                Add-Failure "implementation-coordinator missing agent-first policy: $requiredText"
            }
        }
    }

    if (Test-Path -LiteralPath $intakePlanner) {
        $intakeText = Get-Content -LiteralPath $intakePlanner -Raw
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
            if (-not (Test-PolicyPattern $intakeText $requiredText)) {
                Add-Failure "intake-planner missing agent-first intake policy: $requiredText"
            }
        }
    }

    if (Test-Path -LiteralPath $codeReviewer) {
        $reviewText = Get-Content -LiteralPath $codeReviewer -Raw
        foreach ($requiredText in @(
            '/feedback',
            'participate early',
            'review scope, success criteria, risk, and likely regression surfaces',
            'Return `Next` as actionable next-stage input, not completion proof.'
        )) {
            if (-not (Test-PolicyPattern $reviewText $requiredText)) {
                Add-Failure "code-reviewer missing feedback routing policy: $requiredText"
            }
        }
    }

    if (Test-Path -LiteralPath $verificationRunner) {
        $verificationText = Get-Content -LiteralPath $verificationRunner -Raw
        foreach ($requiredText in @(
            'agents used or skipped',
            'whether agent results were reflected',
            'TaskResult: not requested; not created',
            'Report whether TaskResult was explicitly requested',
            'Git: not requested; git-operator not used',
            'TaskResult is created only when the user explicitly says `TaskResult`, `result report`, `HTML report`, `결과 HTML`, `작업 결과 파일`',
            'Report whether git was explicitly requested'
        )) {
            if (-not (Test-PolicyPattern $verificationText $requiredText)) {
                Add-Failure "verification-runner missing final reporting policy: $requiredText"
            }
        }
    }

    $workflowGuardrails = Join-Path $agentsDir "01-workflow-guardrails.toml"
    if (Test-Path -LiteralPath $workflowGuardrails) {
        $workflowText = Get-Content -LiteralPath $workflowGuardrails -Raw
        foreach ($requiredText in @(
            '@dotnet-harness',
            'Delegation Permission: not explicit',
            'direct-main opt-out wording',
            'safety, approval, validation, TaskResult, and git gates active'
        )) {
            if (-not (Test-PolicyPattern $workflowText $requiredText)) {
                Add-Failure "workflow-guardrails missing automatic handoff policy: $requiredText"
            }
        }
    }

    $gitOperator = Join-Path $agentsDir "11-git-operator.toml"
    if (Test-Path -LiteralPath $gitOperator) {
        $gitText = Get-Content -LiteralPath $gitOperator -Raw
        foreach ($requiredText in @(
            'Only operate on git state when the user explicitly asks for commit, push, PR, merge, reset, clean, branch, or worktree actions.'
        )) {
            if (-not (Test-PolicyPattern $gitText $requiredText)) {
                Add-Failure "git-operator missing explicit git request policy: $requiredText"
            }
        }
    }

    if (Test-Path -LiteralPath $ensureCavemanScript) {
        $ensureCavemanText = Get-Content -LiteralPath $ensureCavemanScript -Raw
        foreach ($requiredText in @(
            'SkillRoot = (Join-Path $HOME ".agents\skills\caveman")',
            'Refusing to install caveman outside the repo without -AllowUserSkillInstall',
            '-AllowUserSkillInstall',
            '-SkillSource <path-to-caveman-skill>'
        )) {
            if (-not (Test-PolicyPattern $ensureCavemanText $requiredText)) {
                Add-Failure "ensure-caveman-skill missing sandbox-safe optional install policy: $requiredText"
            }
        }
    }

    if (Test-Path -LiteralPath $writeTaskResultScript) {
        $writeTaskResultText = Get-Content -LiteralPath $writeTaskResultScript -Raw
        foreach ($requiredText in @(
            'ArchiveDir',
            'NoPrune',
            '--archive-dir',
            '--no-prune'
        )) {
            if (-not (Test-PolicyPattern $writeTaskResultText $requiredText)) {
                Add-Failure "write-task-result wrapper missing retention option: $requiredText"
            }
        }
    }

    if (Test-Path -LiteralPath $writeTaskResultPython) {
        $writeTaskResultPythonText = Get-Content -LiteralPath $writeTaskResultPython -Raw
        foreach ($requiredText in @(
            'archive_dir',
            'no_prune',
            'old.replace(target)',
            '--no-prune'
        )) {
            if (-not (Test-PolicyPattern $writeTaskResultPythonText $requiredText)) {
                Add-Failure "write_task_result.py missing archive-based retention policy: $requiredText"
            }
        }
        if ($writeTaskResultPythonText -match '\.unlink\(') {
            Add-Failure "write_task_result.py must not delete old TaskResult files with unlink()."
        }
    }

    $compressedReturnAgents = @(
        "03-service-template.toml",
        "04-frontend-ui.toml",
        "05-tdd-test.toml",
        "06-reference-auditor.toml",
        "08-implementation-coordinator.toml",
        "09-code-reviewer.toml",
        "10-verification-runner.toml",
        "12-backend-worker.toml",
        "13-frontend-worker.toml",
        "14-test-worker.toml",
        "15-docs-harness-worker.toml",
        "16-backend-reviewer.toml",
        "17-frontend-reviewer.toml",
        "18-test-reviewer.toml",
        "19-docs-harness-reviewer.toml",
        "20-feature-slicer.toml",
        "21-docs-harness-specialist.toml"
    )
    foreach ($agentName in $compressedReturnAgents) {
        $agentPath = Join-Path $agentsDir $agentName
        if (-not (Test-Path -LiteralPath $agentPath)) {
            continue
        }
        $agentText = Get-Content -LiteralPath $agentPath -Raw
        foreach ($requiredText in @(
            "caveman full",
            "Findings",
            "Changes",
            "Risks",
            "Verify",
            "Next",
            "Preserve exact file paths, commands, errors, API names"
        )) {
            if (-not (Test-PolicyPattern $agentText $requiredText)) {
                Add-Failure "$agentName missing compressed return policy: $requiredText"
            }
        }
    }

    $workerPolicies = @{
        "12-backend-worker.toml" = "standard,deep"
        "13-frontend-worker.toml" = "standard,deep"
        "14-test-worker.toml" = "standard,deep"
        "15-docs-harness-worker.toml" = "standard,deep"
    }
    foreach ($workerName in $workerPolicies.Keys) {
        $workerPath = Join-Path $agentsDir $workerName
        if (-not (Test-Path -LiteralPath $workerPath)) {
            continue
        }
        $workerText = Get-Content -LiteralPath $workerPath -Raw
        foreach ($requiredText in @(
            'Require workflow mode input; refuse `lightweight` and run only in `standard` or `deep`.',
            'Require allowed paths, forbidden paths, parallel eligibility, expected changed files, validation evidence, and stop condition.'
        )) {
            if (-not (Test-PolicyPattern $workerText $requiredText)) {
                Add-Failure "$workerName missing worker mode gate policy: $requiredText"
            }
        }
    }

    $reviewerPolicies = @{
        "16-backend-reviewer.toml" = "backend feature-slice reviewer"
        "17-frontend-reviewer.toml" = "frontend feature-slice reviewer"
        "18-test-reviewer.toml" = "test and validation feature-slice reviewer"
        "19-docs-harness-reviewer.toml" = "docs and harness feature-slice reviewer"
    }
    foreach ($reviewerName in $reviewerPolicies.Keys) {
        $reviewerPath = Join-Path $agentsDir $reviewerName
        if (-not (Test-Path -LiteralPath $reviewerPath)) {
            continue
        }
        $reviewerText = Get-Content -LiteralPath $reviewerPath -Raw
        foreach ($requiredText in @(
            $reviewerPolicies[$reviewerName],
            'Review only the assigned feature slice',
            'Do not perform broad whole-repo review',
            'Refuse unclear handoff that lacks feature slice, allowed paths, success criteria, changed files or diff scope, and validation evidence.',
            'Keep review bounded to the assigned feature slice.'
        )) {
            if (-not (Test-PolicyPattern $reviewerText $requiredText)) {
                Add-Failure "$reviewerName missing feature-slice review policy: $requiredText"
            }
        }
    }

    $featureScopedSpecialists = @(
        "03-service-template.toml",
        "04-frontend-ui.toml",
        "05-tdd-test.toml",
        "06-reference-auditor.toml",
        "21-docs-harness-specialist.toml"
    )
    foreach ($specialistName in $featureScopedSpecialists) {
        $specialistPath = Join-Path $agentsDir $specialistName
        if (-not (Test-Path -LiteralPath $specialistPath)) {
            continue
        }
        $specialistText = Get-Content -LiteralPath $specialistPath -Raw
        foreach ($requiredText in @(
            'assigned feature slice',
            'Analyze only the assigned feature slice',
            'allowed paths',
            'success criteria',
            'validation evidence'
        )) {
            if (-not (Test-PolicyPattern $specialistText $requiredText)) {
                Add-Failure "$specialistName missing feature-scoped specialist policy: $requiredText"
            }
        }
    }

    $featureSlicer = Join-Path $agentsDir "20-feature-slicer.toml"
    if (Test-Path -LiteralPath $featureSlicer) {
        $featureSlicerText = Get-Content -LiteralPath $featureSlicer -Raw
        foreach ($requiredText in @(
            'Split the accepted goal into feature slices',
            'allowed paths',
            'forbidden paths',
            'dependency order',
            'parallel eligibility',
            'validation evidence',
            'stop condition'
        )) {
            if (-not (Test-PolicyPattern $featureSlicerText $requiredText)) {
                Add-Failure "feature-slicer missing slice contract: $requiredText"
            }
        }
    }
}

$repoName = Split-Path -Path $RepoRoot -Leaf
$repoPath = (Resolve-Path -LiteralPath $RepoRoot).Path
$repoPathEscaped = [regex]::Escape($repoPath)
$hardcodePatterns = @(
    $repoPathEscaped,
    "Test\\$([regex]::Escape($repoName))",
    "workflow-agent-orchestration",
    "Rev[0-9]{2}"
)
$hardcodeScopes = @(
    $agentsDir,
    $rootAgents
)

foreach ($scope in $hardcodeScopes) {
    if (Test-Path -LiteralPath $scope) {
        if ((Get-Item -LiteralPath $scope).PSIsContainer) {
            $searchFiles = Get-ChildItem -LiteralPath $scope -File -Recurse
        }
        else {
            $searchFiles = @(Get-Item -LiteralPath $scope)
        }

        foreach ($pattern in $hardcodePatterns) {
            $matches = $searchFiles | Select-String -Pattern $pattern -ErrorAction SilentlyContinue
            foreach ($match in $matches) {
                Add-Failure "Hardcode pattern '$pattern' found: $($match.Path):$($match.LineNumber)"
            }
        }
    }
}

foreach ($scope in @($agentsDir, $rootAgents)) {
    if (Test-Path -LiteralPath $scope) {
        if ((Get-Item -LiteralPath $scope).PSIsContainer) {
            $searchFiles = Get-ChildItem -LiteralPath $scope -File -Recurse
        }
        else {
            $searchFiles = @(Get-Item -LiteralPath $scope)
        }

        $localSkillRefs = $searchFiles | Select-String -Pattern "\.codex[/\\]skills" -ErrorAction SilentlyContinue
        foreach ($match in $localSkillRefs) {
            Add-Failure "Repo-local skill reference found: $($match.Path):$($match.LineNumber)"
        }
    }
}

& git -C $RepoRoot rev-parse --show-toplevel *> $null
$gitRoot = if ($LASTEXITCODE -eq 0) { (& git -C $RepoRoot rev-parse --show-toplevel).Trim() } else { $null }
if ($gitRoot) {
    & git -C $RepoRoot diff --check -- ".codex\agents" "AGENTS.md"
    if ($LASTEXITCODE -ne 0) {
        Add-Failure "git diff --check failed"
    }
}
else {
    Write-Host "Skipping git diff --check: not a git repository."
}

if ($failures.Count -gt 0) {
    Write-Host "Task agents validation failed:"
    foreach ($failure in $failures) {
        Write-Host "- $failure"
    }
    exit 1
}

Write-Host "Task agents validation passed."
