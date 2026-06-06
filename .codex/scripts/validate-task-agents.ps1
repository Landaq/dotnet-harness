param(
    [string]$RepoRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
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
$taskAgentsSkill = Join-Path $RepoRoot ".codex\skills\task-agents\SKILL.md"
$rootAgents = Join-Path $RepoRoot "AGENTS.md"

Require-Path $agentsDir
Require-Path $taskAgentsSkill
Require-Path $rootAgents

$requiredAgents = @(
    "01-workflow-guardrails.toml",
    "02-service-template.toml",
    "03-frontend-ui.toml",
    "04-tdd-test.toml",
    "05-reference-auditor.toml",
    "06-intake-planner.toml",
    "07-implementation-coordinator.toml",
    "08-code-reviewer.toml",
    "09-verification-runner.toml",
    "10-git-operator.toml"
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
    }

    if ($content -notmatch '(?ms)^developer_instructions\s*=\s*""".+?"""') {
        Add-Failure "$($agentFile.Name) invalid developer_instructions multiline block"
    }

    $tripleQuoteCount = ([regex]::Matches($content, '"""')).Count
    if (($tripleQuoteCount % 2) -ne 0) {
        Add-Failure "$($agentFile.Name) unbalanced triple quotes"
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
                $relativePath = Resolve-Path -LiteralPath $match.Path -Relative
                $line = $match.Line.Trim()
                $allowedGlobalPointer = $relativePath -eq ".\AGENTS.md" -and $line -like "*C:\Users\cwnv2002\.codex\AGENTS.md*"
                if (-not $allowedGlobalPointer) {
                    Add-Failure "Hardcode pattern '$pattern' found: $($match.Path):$($match.LineNumber)"
                }
            }
        }
    }
}

$quickValidate = Join-Path $env:USERPROFILE ".codex\skills\.system\skill-creator\scripts\quick_validate.py"
if (Test-Path -LiteralPath $quickValidate) {
    & python $quickValidate ".codex\skills\task-agents"
    if ($LASTEXITCODE -ne 0) {
        Add-Failure "quick_validate.py failed for task-agents"
    }
}
else {
    Add-Failure "quick_validate.py not found: $quickValidate"
}

& git diff --check -- ".codex\agents" ".codex\skills\task-agents" "AGENTS.md"
if ($LASTEXITCODE -ne 0) {
    Add-Failure "git diff --check failed"
}

if ($failures.Count -gt 0) {
    Write-Host "Task agents validation failed:"
    foreach ($failure in $failures) {
        Write-Host "- $failure"
    }
    exit 1
}

Write-Host "Task agents validation passed."
