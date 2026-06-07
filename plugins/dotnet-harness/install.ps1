param(
    [string]$Root = (Get-Location).Path,
    [string]$ProjectName,
    [string]$ServiceName,
    [switch]$HarnessOnly,
    [switch]$Preview,
    [switch]$NoGitkeep,
    [switch]$InstallOptionalSkills
)

$ErrorActionPreference = "Stop"
$env:PYTHONUTF8 = "1"

$bootstrap = Join-Path $PSScriptRoot "skills\project-structure-setup\scripts\bootstrap_project_structure.py"
if (-not (Test-Path -LiteralPath $bootstrap)) {
    throw "Missing bootstrap script: $bootstrap"
}

$arguments = @($bootstrap, "--root", $Root)

if ($ProjectName) {
    $arguments += @("--project-name", $ProjectName)
}

if ($ServiceName) {
    $arguments += @("--service-name", $ServiceName)
}

if ($HarnessOnly) {
    $arguments += "--harness-only"
}

if ($Preview) {
    $arguments += "--preview"
}

if ($NoGitkeep) {
    $arguments += "--no-gitkeep"
}

if ($InstallOptionalSkills) {
    $arguments += "--install-optional-skills"
}

& python @arguments
exit $LASTEXITCODE
