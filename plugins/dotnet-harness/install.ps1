param(
    [string]$Root = (Get-Location).Path,
    [string]$ProjectName,
    [string]$ServiceName,
    [switch]$NoService,
    [switch]$HarnessOnly,
    [switch]$Preview,
    [switch]$NoGitkeep,
    [switch]$InstallOptionalSkills,
    [switch]$SkipHarnessUpgrade
)

$ErrorActionPreference = "Stop"
$env:PYTHONUTF8 = "1"

$bootstrap = Join-Path $PSScriptRoot "skills\project-structure-setup\scripts\bootstrap_project_structure.py"
if (-not (Test-Path -LiteralPath $bootstrap)) {
    throw "Missing bootstrap script: $bootstrap"
}

function Test-ExistingHarness {
    param([string]$TargetRoot)

    foreach ($relative in @("AGENTS.md", ".codex\agents", ".codex\scripts", ".codex\skills")) {
        if (Test-Path -LiteralPath (Join-Path $TargetRoot $relative)) {
            return $true
        }
    }

    return $false
}

$resolvedRoot = [System.IO.Path]::GetFullPath($Root)
$upgradeScript = Join-Path $PSScriptRoot "assets\harness\.codex\scripts\upgrade-harness.ps1"
$harnessSource = Join-Path $PSScriptRoot "assets\harness"

if (-not $SkipHarnessUpgrade -and (Test-ExistingHarness -TargetRoot $resolvedRoot)) {
    if (-not (Test-Path -LiteralPath $upgradeScript)) {
        throw "Missing harness upgrade script: $upgradeScript"
    }

    $upgradeArguments = @(
        "-NoProfile",
        "-File",
        $upgradeScript,
        "-TargetRoot",
        $resolvedRoot,
        "-SourceRoot",
        $harnessSource
    )

    if (-not $Preview) {
        $upgradeArguments += "-Apply"
    }

    if ($InstallOptionalSkills) {
        $upgradeArguments += "-InstallOptionalSkills"
    }

    Write-Host "[upgrade] existing repo-local harness detected: $resolvedRoot"
    & pwsh @upgradeArguments
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    if ($HarnessOnly) {
        exit 0
    }
}

$arguments = @($bootstrap, "--root", $resolvedRoot)

if ($ProjectName) {
    $arguments += @("--project-name", $ProjectName)
}

if ($ServiceName) {
    $arguments += @("--service-name", $ServiceName)
}

if ($NoService) {
    $arguments += "--no-service"
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
