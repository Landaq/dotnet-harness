param(
    [string]$RepoRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
$env:PYTHONUTF8 = "1"

. (Join-Path $PSScriptRoot "python-env.ps1")
$python = Resolve-DotnetHarnessPython

$validator = Join-Path $PSScriptRoot "validate_task_agents.py"
& $python $validator --repo-root $RepoRoot
exit $LASTEXITCODE
