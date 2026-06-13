param(
    [Parameter(Mandatory = $true)]
    [string]$Summary,

    [Parameter(Mandatory = $true)]
    [string]$Request,

    [Parameter(Mandatory = $true)]
    [string]$Work,

    [Parameter(Mandatory = $true)]
    [string]$Result,

    [string]$Todo = "",
    [string]$OutputDir = "docs\TaskResult",
    [string]$ArchiveDir = "",
    [switch]$NoPrune
)

$ErrorActionPreference = "Stop"
$env:PYTHONUTF8 = "1"

$repoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")
$script = Join-Path $PSScriptRoot "write_task_result.py"

if (-not (Test-Path -LiteralPath $script)) {
    throw "Missing task result helper: $script"
}

$arguments = @(
    $script,
    "--summary", $Summary,
    "--request", $Request,
    "--work", $Work,
    "--result", $Result,
    "--todo", $Todo,
    "--output-dir", (Join-Path $repoRoot $OutputDir)
)

if (-not [string]::IsNullOrWhiteSpace($ArchiveDir)) {
    $arguments += @("--archive-dir", (Join-Path $repoRoot $ArchiveDir))
}
if ($NoPrune) {
    $arguments += "--no-prune"
}

& python @arguments
