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
    [string]$OutputDir = "docs\TaskResult"
)

$ErrorActionPreference = "Stop"
$env:PYTHONUTF8 = "1"

$repoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")
$script = Join-Path $PSScriptRoot "write_task_result.py"

if (-not (Test-Path -LiteralPath $script)) {
    $pluginScript = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\..\..\skills\task-agents\scripts\write_task_result.py"))
    if (Test-Path -LiteralPath $pluginScript) {
        $script = $pluginScript
    }
}

if (-not (Test-Path -LiteralPath $script)) {
    throw "Missing task result helper: $script"
}

& python $script `
    --summary $Summary `
    --request $Request `
    --work $Work `
    --result $Result `
    --todo $Todo `
    --output-dir (Join-Path $repoRoot $OutputDir)
