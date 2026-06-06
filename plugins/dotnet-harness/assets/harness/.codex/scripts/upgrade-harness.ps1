param(
    [string]$TargetRoot = (Get-Location).Path,
    [string]$SourceRoot,
    [switch]$Apply,
    [switch]$SkipValidation
)

$ErrorActionPreference = "Stop"
$env:PYTHONUTF8 = "1"

function Resolve-FullPath {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        return (Resolve-Path -LiteralPath $Path).Path
    }
    return [System.IO.Path]::GetFullPath($Path)
}

function Get-DefaultSourceRoot {
    $scriptRoot = Resolve-Path -LiteralPath $PSScriptRoot
    return (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..\..")).Path
}

function Get-SourceSkillsRoot {
    param([string]$Root)
    $localSkills = Join-Path $Root ".codex\skills"
    if (Test-Path -LiteralPath $localSkills) {
        return $localSkills
    }

    $pluginSkills = Resolve-FullPath (Join-Path $PSScriptRoot "..\..\..\..\skills")
    if (Test-Path -LiteralPath $pluginSkills) {
        return $pluginSkills
    }

    throw "Invalid harness source. Missing skills source under $Root or plugin skills."
}

function Assert-HarnessSource {
    param([string]$Root)
    foreach ($required in @("AGENTS.md", ".codex\agents", ".codex\scripts")) {
        $path = Join-Path $Root $required
        if (-not (Test-Path -LiteralPath $path)) {
            throw "Invalid harness source. Missing: $path"
        }
    }
    Get-SourceSkillsRoot -Root $Root | Out-Null
}

function Copy-ExistingToBackup {
    param([string]$Target, [string]$BackupRoot)
    foreach ($relative in @("AGENTS.md", ".codex\agents", ".codex\skills", ".codex\scripts")) {
        $source = Join-Path $Target $relative
        if (Test-Path -LiteralPath $source) {
            $backup = Join-Path $BackupRoot $relative
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backup) | Out-Null
            Copy-Item -LiteralPath $source -Destination $backup -Recurse -Force
            Write-Host "[backup] $source -> $backup"
        }
    }
}

function Copy-HarnessToTarget {
    param([string]$Source, [string]$Target)
    foreach ($relative in @("AGENTS.md", ".codex\agents", ".codex\scripts")) {
        $sourcePath = Join-Path $Source $relative
        $targetPath = Join-Path $Target $relative
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetPath) | Out-Null
        Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Recurse -Force
        Write-Host "[update] $targetPath"
    }

    $skillsSource = Get-SourceSkillsRoot -Root $Source
    $skillsTarget = Join-Path $Target ".codex\skills"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $skillsTarget) | Out-Null
    Copy-Item -LiteralPath $skillsSource -Destination $skillsTarget -Recurse -Force
    Write-Host "[update] $skillsTarget"
}

$target = Resolve-FullPath $TargetRoot
$source = if ($SourceRoot) { Resolve-FullPath $SourceRoot } else { Get-DefaultSourceRoot }

Assert-HarnessSource -Root $source

Write-Host "Harness source: $source"
Write-Host "Target project: $target"

if (-not $Apply) {
    Write-Host "Preview only. Re-run with -Apply to backup and update the target harness."
    exit 0
}

New-Item -ItemType Directory -Force -Path $target | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupRoot = Join-Path $target ".codex\backups\harness-upgrade-$stamp"
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

Copy-ExistingToBackup -Target $target -BackupRoot $backupRoot
Copy-HarnessToTarget -Source $source -Target $target

if (-not $SkipValidation) {
    $validator = Join-Path $target ".codex\scripts\validate-task-agents.ps1"
    if (Test-Path -LiteralPath $validator) {
        & pwsh -NoProfile -File $validator -RepoRoot $target
        if ($LASTEXITCODE -ne 0) {
            throw "Harness validation failed after upgrade. Backup: $backupRoot"
        }
    }
}

Write-Host "Harness upgrade complete. Backup: $backupRoot"
