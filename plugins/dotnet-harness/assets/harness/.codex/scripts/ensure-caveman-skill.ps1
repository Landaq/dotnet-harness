param(
    [string]$SkillRoot = (Join-Path $HOME ".agents\skills\caveman"),
    [string]$SkillSource,
    [switch]$AllowUserSkillInstall,
    [switch]$Apply
)

$ErrorActionPreference = "Stop"

function Resolve-FullPathIfExists {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }
    if (Test-Path -LiteralPath $Path) {
        return (Resolve-Path -LiteralPath $Path).Path
    }
    return [System.IO.Path]::GetFullPath($Path)
}

function Get-DefaultSkillSource {
    $scriptRoot = (Resolve-Path -LiteralPath $PSScriptRoot).Path
    $candidates = @(
        (Join-Path $scriptRoot "..\..\..\optional-skills\caveman"),
        (Join-Path $scriptRoot "..\..\..\..\optional-skills\caveman")
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath (Join-Path $candidate "SKILL.md")) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    return $null
}

function Test-CavemanSkill {
    param([string]$Root)
    return (Test-Path -LiteralPath (Join-Path $Root "SKILL.md"))
}

function Copy-CavemanSkill {
    param([string]$Source, [string]$Target)

    if (-not (Test-Path -LiteralPath (Join-Path $Source "SKILL.md"))) {
        throw "Invalid caveman skill source. Missing SKILL.md: $Source"
    }

    if (Test-Path -LiteralPath $Target) {
        throw "Refusing to overwrite existing skill directory: $Target"
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Target) | Out-Null
    Copy-Item -LiteralPath $Source -Destination $Target -Recurse
    Write-Host "[create] caveman skill: $Target"
}

$skillRootPath = Resolve-FullPathIfExists $SkillRoot
if (Test-CavemanSkill -Root $skillRootPath) {
    Write-Host "[exists] caveman skill: $skillRootPath"
    exit 0
}

$source = if ($SkillSource) { Resolve-FullPathIfExists $SkillSource } else { Get-DefaultSkillSource }

if (-not $Apply) {
    Write-Host "[preview] caveman skill missing: $skillRootPath"
    if ($source) {
        Write-Host "[preview] install with: pwsh -NoProfile -File .codex\scripts\ensure-caveman-skill.ps1 -Apply"
    }
    else {
        Write-Host "[preview] install with: pwsh -NoProfile -File .codex\scripts\ensure-caveman-skill.ps1 -Apply -SkillSource <path-to-caveman-skill>"
    }
    exit 0
}

if (-not $AllowUserSkillInstall) {
    throw "Refusing to install caveman outside the repo without -AllowUserSkillInstall. Re-run only after explicit user approval."
}

if (-not $source) {
    throw "Caveman skill missing and no install source was found. Re-run with -SkillSource <path-to-caveman-skill>."
}

Copy-CavemanSkill -Source $source -Target $skillRootPath
