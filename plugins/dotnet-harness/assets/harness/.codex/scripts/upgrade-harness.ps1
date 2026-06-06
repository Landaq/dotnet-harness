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
    $backupItems = @(
        @{ Source = "AGENTS.md"; Backup = "AGENTS.md" },
        @{ Source = ".codex\agents"; Backup = "agents-backup" },
        @{ Source = ".codex\skills"; Backup = "skills-backup" },
        @{ Source = ".codex\scripts"; Backup = "scripts-backup" }
    )

    foreach ($item in $backupItems) {
        $relative = $item.Source
        $source = Join-Path $Target $relative
        if (Test-Path -LiteralPath $source) {
            $backup = Join-Path $BackupRoot $item.Backup
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backup) | Out-Null
            Copy-Item -LiteralPath $source -Destination $backup -Recurse -Force
            Write-Host "[backup] $source -> $backup"
        }
    }
}

function Copy-HarnessToTarget {
    param([string]$Source, [string]$Target)

    $rootFiles = @(".gitignore", ".gitattributes")
    foreach ($relative in $rootFiles) {
        $sourcePath = Join-Path $Source $relative
        $targetPath = Join-Path $Target $relative
        if ((Test-Path -LiteralPath $sourcePath) -and -not (Test-Path -LiteralPath $targetPath)) {
            Copy-Item -LiteralPath $sourcePath -Destination $targetPath
            Write-Host "[create] $targetPath"
        }
        elseif (Test-Path -LiteralPath $targetPath) {
            Write-Host "[skip] exists: $targetPath"
        }
    }

    foreach ($relative in @("AGENTS.md")) {
        $sourcePath = Join-Path $Source $relative
        $targetPath = Join-Path $Target $relative
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetPath) | Out-Null
        Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Recurse -Force
        Write-Host "[update] $targetPath"
    }

    foreach ($relative in @(".codex\agents", ".codex\scripts")) {
        $sourcePath = Join-Path $Source $relative
        $targetPath = Join-Path $Target $relative
        if (Test-Path -LiteralPath $targetPath) {
            Remove-Item -LiteralPath $targetPath -Recurse -Force
        }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetPath) | Out-Null
        Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Recurse -Force
        Write-Host "[replace] $targetPath"
    }

    $skillsSource = Get-SourceSkillsRoot -Root $Source
    $skillsTarget = Join-Path $Target ".codex\skills"
    if (Test-Path -LiteralPath $skillsTarget) {
        Remove-Item -LiteralPath $skillsTarget -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $skillsTarget) | Out-Null
    Copy-Item -LiteralPath $skillsSource -Destination $skillsTarget -Recurse -Force
    Write-Host "[replace] $skillsTarget"
}

function Write-Preview {
    param([string]$Source, [string]$Target)

    Write-Host "Preview only. Re-run with -Apply to backup and update the target harness."
    foreach ($relative in @(".gitignore", ".gitattributes")) {
        $sourcePath = Join-Path $Source $relative
        $targetPath = Join-Path $Target $relative
        if ((Test-Path -LiteralPath $sourcePath) -and -not (Test-Path -LiteralPath $targetPath)) {
            Write-Host "[preview] create $targetPath"
        }
        elseif (Test-Path -LiteralPath $targetPath) {
            Write-Host "[preview] skip existing $targetPath"
        }
    }

    Write-Host "[preview] backup AGENTS.md, .codex\agents, .codex\skills, .codex\scripts"
    Write-Host "[preview] replace active .codex\agents with source harness agents"
    Write-Host "[preview] replace active .codex\skills with source harness skills"
    Write-Host "[preview] replace active .codex\scripts with source harness scripts"
    Write-Host "[preview] backup agents are stored outside active .codex\agents discovery paths"
}

$target = Resolve-FullPath $TargetRoot
$source = if ($SourceRoot) { Resolve-FullPath $SourceRoot } else { Get-DefaultSourceRoot }

Assert-HarnessSource -Root $source

Write-Host "Harness source: $source"
Write-Host "Target project: $target"

if (-not $Apply) {
    Write-Preview -Source $source -Target $target
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
