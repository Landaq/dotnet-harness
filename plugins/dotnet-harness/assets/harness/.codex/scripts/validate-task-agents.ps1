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

function Require-Path {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        Add-Failure "Missing path: $Path"
    }
}

$agentsDir = Join-Path $RepoRoot ".codex\agents"
$skillsDir = Join-Path $RepoRoot ".codex\skills"
$rootAgents = Join-Path $RepoRoot "AGENTS.md"

Require-Path $agentsDir
Require-Path $rootAgents
Require-Path (Join-Path $RepoRoot ".codex\scripts\ensure-caveman-skill.ps1")

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
    "11-git-operator.toml"
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
            "If the average remains above 8% or the answer shifts the target goal",
            "Socratic: satisfied",
            "Goal Alignment"
        )) {
            if ($goalBoundaryText -notmatch [regex]::Escape($requiredText)) {
                Add-Failure "goal-boundary missing Socratic reassessment policy: $requiredText"
            }
        }
    }

    if (Test-Path -LiteralPath $implementationCoordinator) {
        $implementationText = Get-Content -LiteralPath $implementationCoordinator -Raw
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
            if ($implementationText -notmatch [regex]::Escape($requiredText)) {
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
            'agent-first orchestration request',
            'planning, implementation, feedback/code-review, and verification should be assigned to discovered repo-local agents',
            'For backend non-trivial work, route pre-implementation analysis to `service-template` and `tdd-test`.',
            'Delegation: skipped user-opt-out'
        )) {
            if ($intakeText -notmatch [regex]::Escape($requiredText)) {
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
            if ($reviewText -notmatch [regex]::Escape($requiredText)) {
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
            if ($verificationText -notmatch [regex]::Escape($requiredText)) {
                Add-Failure "verification-runner missing final reporting policy: $requiredText"
            }
        }
    }

    $workflowGuardrails = Join-Path $agentsDir "01-workflow-guardrails.toml"
    if (Test-Path -LiteralPath $workflowGuardrails) {
        $workflowText = Get-Content -LiteralPath $workflowGuardrails -Raw
        foreach ($requiredText in @(
            '@dotnet-harness',
            'agent-first handoff triggers',
            'direct-main opt-out wording',
            'safety, approval, validation, TaskResult, and git gates active'
        )) {
            if ($workflowText -notmatch [regex]::Escape($requiredText)) {
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
            if ($gitText -notmatch [regex]::Escape($requiredText)) {
                Add-Failure "git-operator missing explicit git request policy: $requiredText"
            }
        }
    }

    $compressedReturnAgents = @(
        "03-service-template.toml",
        "04-frontend-ui.toml",
        "05-tdd-test.toml",
        "06-reference-auditor.toml",
        "08-implementation-coordinator.toml",
        "09-code-reviewer.toml",
        "10-verification-runner.toml"
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
            if ($agentText -notmatch [regex]::Escape($requiredText)) {
                Add-Failure "$agentName missing compressed return policy: $requiredText"
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
