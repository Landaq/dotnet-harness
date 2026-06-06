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
$rootAgents = Join-Path $RepoRoot "AGENTS.md"

function Get-SkillsRoot {
    $localSkills = Join-Path $RepoRoot ".codex\skills"
    if (Test-Path -LiteralPath $localSkills) {
        return $localSkills
    }

    $pluginSkills = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\..\..\skills"))
    if (Test-Path -LiteralPath $pluginSkills) {
        return $pluginSkills
    }

    return $localSkills
}

$skillsRoot = Get-SkillsRoot
$taskAgentsSkill = Join-Path $skillsRoot "task-agents\SKILL.md"

Require-Path $agentsDir
Require-Path $taskAgentsSkill
Require-Path $rootAgents

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
    }
}

$repoName = Split-Path -Path $RepoRoot -Leaf
$repoPath = (Resolve-Path -LiteralPath $RepoRoot).Path
$repoPathEscaped = [regex]::Escape($repoPath)
$hardcodePatterns = @(
    [regex]::Escape($repoName),
    $repoPathEscaped,
    "Test\\$([regex]::Escape($repoName))",
    "workflow-agent-orchestration",
    "Rev[0-9]{2}"
)
$hardcodeScopes = @(
    $agentsDir,
    $taskAgentsSkill,
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

$quickValidate = Join-Path $env:USERPROFILE ".codex\skills\.system\skill-creator\scripts\quick_validate.py"
if ((Test-Path -LiteralPath $quickValidate) -and (Test-Path -LiteralPath $taskAgentsSkill)) {
    & python $quickValidate (Join-Path $skillsRoot "task-agents")
    if ($LASTEXITCODE -ne 0) {
        Add-Failure "quick_validate.py failed for task-agents"
    }
}
elseif (-not (Test-Path -LiteralPath $quickValidate)) {
    Add-Failure "quick_validate.py not found: $quickValidate"
}
else {
    Add-Failure "task-agents skill folder not found: $(Join-Path $RepoRoot ".codex\skills\task-agents")"
}

& git -C $RepoRoot rev-parse --show-toplevel *> $null
$gitRoot = if ($LASTEXITCODE -eq 0) { (& git -C $RepoRoot rev-parse --show-toplevel).Trim() } else { $null }
if ($gitRoot -and (Test-Path -LiteralPath (Join-Path $RepoRoot ".codex\skills"))) {
    & git -C $RepoRoot diff --check -- ".codex\agents" ".codex\skills\task-agents" "AGENTS.md"
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
