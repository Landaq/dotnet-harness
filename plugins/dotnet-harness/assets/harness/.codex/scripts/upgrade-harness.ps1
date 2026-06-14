param(
    [string]$TargetRoot = (Get-Location).Path,
    [string]$SourceRoot,
    [switch]$Apply,
    [switch]$SkipValidation,
    [switch]$InstallOptionalSkills
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

function Assert-HarnessSource {
    param([string]$Root)
    foreach ($required in @("AGENTS.md", ".codex\agents", ".codex\scripts")) {
        $path = Join-Path $Root $required
        if (-not (Test-Path -LiteralPath $path)) {
            throw "Invalid harness source. Missing: $path"
        }
    }
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

function Move-ToBackupFile {
    param([string]$Path)

    $destination = "$Path.bak"
    if (Test-Path -LiteralPath $destination) {
        $destination = "$Path.$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()).bak"
    }

    Move-Item -LiteralPath $Path -Destination $destination -Force
    Write-Host "[protect] $Path -> $destination"
}

function Protect-BackupFromDiscovery {
    param([string]$BackupsRoot)

    if (-not (Test-Path -LiteralPath $BackupsRoot)) {
        return
    }

    $backupFiles = Get-ChildItem -LiteralPath $BackupsRoot -Recurse -File
    foreach ($agentFile in $backupFiles | Where-Object {
        $_.Name -like "*.toml" -and (
            $_.FullName -match "\\agents-backup\\" -or
            $_.FullName -match "\\\.codex\\agents\\"
        )
    }) {
        Move-ToBackupFile -Path $agentFile.FullName
    }

    foreach ($skillFile in $backupFiles | Where-Object {
        $_.Name -eq "SKILL.md" -and (
            $_.FullName -match "\\skills-backup\\" -or
            $_.FullName -match "\\\.codex\\skills\\"
        )
    }) {
        Move-ToBackupFile -Path $skillFile.FullName
    }

    $agentsBackupRoot = Join-Path $BackupsRoot "agents-backup"
    if (Test-Path -LiteralPath $agentsBackupRoot) {
        foreach ($agentFile in Get-ChildItem -LiteralPath $agentsBackupRoot -Recurse -File -Filter "*.toml") {
            Move-ToBackupFile -Path $agentFile.FullName
        }
    }

    $skillsBackupRoot = Join-Path $BackupsRoot "skills-backup"
    if (Test-Path -LiteralPath $skillsBackupRoot) {
        foreach ($skillFile in Get-ChildItem -LiteralPath $skillsBackupRoot -Recurse -File -Filter "SKILL.md") {
            Move-ToBackupFile -Path $skillFile.FullName
        }
    }
}

function Copy-HarnessToTarget {
    param([string]$Source, [string]$Target)

    $rootFiles = @(".gitignore", ".gitattributes", ".codex\harness-config.json")
    foreach ($relative in $rootFiles) {
        $sourcePath = Join-Path $Source $relative
        $targetPath = Join-Path $Target $relative
        if ((Test-Path -LiteralPath $sourcePath) -and -not (Test-Path -LiteralPath $targetPath)) {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetPath) | Out-Null
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

    $skillsTarget = Join-Path $Target ".codex\skills"
    if (Test-Path -LiteralPath $skillsTarget) {
        Remove-Item -LiteralPath $skillsTarget -Recurse -Force
        Write-Host "[remove] $skillsTarget"
    }
}

function Write-Preview {
    param([string]$Source, [string]$Target)

    Write-Host "Preview only. Re-run with -Apply to backup and update the target harness."
    foreach ($relative in @(".gitignore", ".gitattributes", ".codex\harness-config.json")) {
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
    Write-Host "[preview] remove active .codex\skills after backup; plugin skills remain the source"
    Write-Host "[preview] replace active .codex\scripts with source harness scripts"
    Write-Host "[preview] backup agent .toml files and skill SKILL.md files are renamed to .bak to avoid active discovery"
}

function Invoke-CavemanSkillCheck {
    param(
        [string]$ScriptRoot,
        [string]$HarnessSource,
        [switch]$ApplyInstall
    )

    $script = Join-Path $ScriptRoot ".codex\scripts\ensure-caveman-skill.ps1"
    if (-not (Test-Path -LiteralPath $script)) {
        Write-Host "[skip] missing optional skill helper: $script"
        return
    }

    $optionalSource = Join-Path (Split-Path -Parent $HarnessSource) "optional-skills\caveman"
    $arguments = @("-NoProfile", "-File", $script)
    if (Test-Path -LiteralPath (Join-Path $optionalSource "SKILL.md")) {
        $arguments += @("-SkillSource", $optionalSource)
    }
    if ($ApplyInstall) {
        $arguments += "-Apply"
        $arguments += "-AllowUserSkillInstall"
    }

    try {
        & pwsh @arguments
    }
    catch {
        Write-Host "[warn] caveman optional skill check failed: $($_.Exception.Message)"
    }
}

$target = Resolve-FullPath $TargetRoot
$source = if ($SourceRoot) { Resolve-FullPath $SourceRoot } else { Get-DefaultSourceRoot }

Assert-HarnessSource -Root $source

Write-Host "Harness source: $source"
Write-Host "Target project: $target"

if (-not $Apply) {
    Write-Preview -Source $source -Target $target
    Invoke-CavemanSkillCheck -ScriptRoot $source -HarnessSource $source
    exit 0
}

New-Item -ItemType Directory -Force -Path $target | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupRoot = Join-Path $target ".codex\backups\harness-upgrade-$stamp"
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

Copy-ExistingToBackup -Target $target -BackupRoot $backupRoot
$backupsRoot = Join-Path $target ".codex\backups"
Protect-BackupFromDiscovery -BackupsRoot $backupsRoot
Copy-HarnessToTarget -Source $source -Target $target
Invoke-CavemanSkillCheck -ScriptRoot $target -HarnessSource $source -ApplyInstall:$InstallOptionalSkills

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
