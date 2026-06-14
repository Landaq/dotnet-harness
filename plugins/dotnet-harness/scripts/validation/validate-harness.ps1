param(
    [string]$PluginRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
)

. (Join-Path $PSScriptRoot "common.ps1")
$ctx = Get-DotnetHarnessValidationContext -PluginRoot $PluginRoot

Invoke-ValidationStep "harness task agents" {
    if (-not (Test-Path -LiteralPath $ctx.HarnessValidator)) {
        throw "Missing harness validator: $($ctx.HarnessValidator)"
    }
    & pwsh -NoProfile -File $ctx.HarnessValidator -RepoRoot $ctx.HarnessRoot
    if ($LASTEXITCODE -ne 0) {
        throw "Harness task agent validation failed."
    }
}

Invoke-ValidationStep "agent schema compatibility" {
    $unsupportedPolicyTables = Get-ChildItem -LiteralPath (Join-Path $ctx.HarnessRoot ".codex\agents") -Filter "*.toml" -File |
        Select-String -Pattern "^\s*\[policy\]" -ErrorAction SilentlyContinue
    if ($unsupportedPolicyTables) {
        throw "Generated repo-local agents must not contain unsupported [policy] tables."
    }

    $harnessPolicyFiles = @(
        Get-Item -LiteralPath (Join-Path $ctx.HarnessRoot "AGENTS.md")
        Get-ChildItem -LiteralPath (Join-Path $ctx.HarnessRoot ".codex\agents") -File -Filter "*.toml"
    )
    $localSkillRefs = $harnessPolicyFiles | Select-String -Pattern "\.codex[/\\]skills" -ErrorAction SilentlyContinue
    if ($localSkillRefs) {
        throw "Harness agents/AGENTS.md must reference dotnet-harness:* plugin skills, not .codex/skills."
    }
}

Invoke-ValidationStep "task-agents routing contract" {
    $taskAgents = Get-Content -LiteralPath $ctx.TaskAgentsSkill -Raw
    $taskAgentsReferences = Join-Path (Split-Path -Path $ctx.TaskAgentsSkill -Parent) "references"
    $taskAgentsPolicy = $taskAgents
    foreach ($referenceFile in Get-ChildItem -LiteralPath $taskAgentsReferences -File -Filter "*.md" | Sort-Object Name) {
        $taskAgentsPolicy += "`n" + (Get-Content -LiteralPath $referenceFile.FullName -Raw)
    }

    foreach ($requiredText in @(
        'Workflow Modes',
        'Clarify Before Delegating',
        'Delegation Evidence',
        'Compressed Agent Handoff',
        'Mandatory Socratic Checkpoint',
        'Subagent Utilization Floor',
        'Task Agents must clarify before delegating. Actual subagent execution begins only after Socratic goal clarification is satisfied and runtime delegation permission is present.',
        'Actual subagent execution means calling an available delegated-agent tool such as `spawn_agent`',
        'Reading agent TOML, summarizing an agent persona, or role-playing a specialist in the main thread does not count as subagent execution.',
        'Delegation: used',
        'Delegation: skipped no-explicit-agent-request',
        'TaskResult remains opt-in only.',
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
        'Every phase must state `Phase`, `Agent`, `Purpose`, `Input Contract`, `Output Contract`, `Handoff Gate`, and `Next Phase`.',
        'Worker agents are `standard`/`deep` only',
        'Parallel: yes',
        'Parallel: no',
        'Ask at least one Korean Socratic question',
        'target average ambiguity `<= 8%`',
        'Recalculate ambiguity percentage for each active feature goal and the average ambiguity after every answer.',
        'Before moving to the next stage, explicitly show the user the recalculated ambiguity and goal alignment result.',
        'Mode: caveman full',
        'Findings:',
        'Changes:',
        'Risks:',
        'Verify:',
        'Next:'
    )) {
        if (-not (Test-PolicyPattern $taskAgentsPolicy $requiredText)) {
            throw "Task Agents must define workflow/delegation behavior: missing '$requiredText'."
        }
    }
}

Invoke-ValidationStep "agent role contracts" {
    $agentFiles = @(
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
    foreach ($agentName in $agentFiles) {
        $agentText = Get-Content -LiteralPath (Join-Path $ctx.HarnessRoot ".codex\agents\$agentName") -Raw
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
                throw "Agent must define compressed handoff behavior: $agentName missing '$requiredText'."
            }
        }
    }

    $implementationText = Get-Content -LiteralPath (Join-Path $ctx.HarnessRoot ".codex\agents\08-implementation-coordinator.toml") -Raw
    foreach ($requiredText in @(
        'Require actual subagent tool calls such as `spawn_agent`',
        'A delegation plan is not delegation evidence.',
        'Do not hand off to the next agent until previous agent output is explicit, bounded, and usable as the next input contract.',
        'Preferred workers are `backend-worker`, `frontend-worker`, `test-worker`, and `docs-harness-worker`.',
        'Route non-trivial multi-area work through `feature-slicer`',
        'Use feature-scoped read-only specialists',
        'specialist assignments',
        'Route post-implementation checks to the smallest relevant reviewer set',
        'Split review work by feature slice.',
        'reviewer assignments by feature slice'
    )) {
        if (-not (Test-PolicyPattern $implementationText $requiredText)) {
            throw "Implementation coordinator missing routing policy: '$requiredText'."
        }
    }
}

Invoke-ValidationStep "helper contracts" {
    foreach ($requiredPath in @($ctx.OptionalCavemanSkill, $ctx.EnsureCavemanScript, $ctx.HarnessConfig)) {
        if (-not (Test-Path -LiteralPath $requiredPath)) {
            throw "Missing harness support file: $requiredPath"
        }
    }

    $harnessConfigText = Get-Content -LiteralPath $ctx.HarnessConfig -Raw
    foreach ($requiredText in @("defaultLibrary", "biLibrary", "devExpressVersion")) {
        if (-not (Test-PolicyPattern $harnessConfigText $requiredText)) {
            throw "Harness config defaults missing required UI key: '$requiredText'."
        }
    }

    $ensureCaveman = Get-Content -LiteralPath $ctx.EnsureCavemanScript -Raw
    foreach ($requiredText in @(
        'SkillRoot = (Join-Path $HOME ".agents\skills\caveman")',
        'Refusing to overwrite existing skill directory',
        'Refusing to install caveman outside the repo without -AllowUserSkillInstall',
        '-AllowUserSkillInstall'
    )) {
        if (-not (Test-PolicyPattern $ensureCaveman $requiredText)) {
            throw "Caveman optional skill helper missing required behavior: '$requiredText'."
        }
    }

    $writeTaskResultScript = Join-Path $ctx.HarnessRoot ".codex\scripts\write-task-result.ps1"
    $writeTaskResultPython = Join-Path $ctx.HarnessRoot ".codex\scripts\write_task_result.py"
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
}

Write-Host "Harness validation passed: $($ctx.PluginRoot)"
