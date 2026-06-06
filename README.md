# Dotnet Harness

이 repo는 .NET 프로젝트를 보조하는 Codex 환경을 플러그인으로 관리하기 위한 저장소입니다. 애플리케이션 소스가 아니라 `dotnet-harness` plugin의 개발, 검증, 배포 원본을 관리합니다.

## 목적

`dotnet-harness`는 새 프로젝트나 기존 프로젝트에 다음 기준의 Codex 작업 환경을 설치합니다.

- Framework: .NET 10
- Orchestration: Aspire
- Architecture: Clean Architecture, DDD
- Backend: ASP.NET Core, EF Core, Minimal API
- API docs: Scalar UI
- Data: SQL Server, Redis
- Proxy: YARP
- Frontend: Blazor Auto Rendering, MudBlazor
- Workflow: repo-local Codex skills, agents, validation scripts

## 주요 위치

- `plugins/dotnet-harness/.codex-plugin/plugin.json`: plugin manifest와 버전
- `plugins/dotnet-harness/skills`: plugin skill 원본
- `plugins/dotnet-harness/assets/harness/AGENTS.md`: 설치 대상 프로젝트용 agent 규칙
- `plugins/dotnet-harness/assets/harness/.codex/agents`: 설치 대상 프로젝트용 agents
- `plugins/dotnet-harness/assets/harness/.codex/scripts`: 설치/검증/업그레이드 helper
- `.agents/plugins/marketplace.json`: repo-local marketplace 등록
## 사용

기존 프로젝트에 harness만 설치:

```powershell
pwsh -NoProfile -File plugins\dotnet-harness\install.ps1 -Root "C:\path\to\project" -ProjectName ExistingProject -HarnessOnly
```

새 .NET 프로젝트 기본 구조까지 설치:

```powershell
pwsh -NoProfile -File plugins\dotnet-harness\install.ps1 -Root "C:\path\to\project" -ProjectName NewProject
```

서비스 scaffold 포함:

```powershell
pwsh -NoProfile -File plugins\dotnet-harness\install.ps1 -Root "C:\path\to\project" -ProjectName NewProject -ServiceName Orders
```

Windows Codex sandbox에서는 Python 스크립트 직접 실행보다 위 PowerShell wrapper를 기본 사용합니다.

기존 harness 업그레이드 preview:

```powershell
pwsh -NoProfile -File plugins\dotnet-harness\assets\harness\.codex\scripts\upgrade-harness.ps1 -TargetRoot "C:\path\to\project"
```

기존 harness 업그레이드 적용:

```powershell
pwsh -NoProfile -File plugins\dotnet-harness\assets\harness\.codex\scripts\upgrade-harness.ps1 -TargetRoot "C:\path\to\project" -Apply
```

업그레이드 적용 시 기존 `AGENTS.md`, `.codex\agents`, `.codex\skills`, `.codex\scripts`는 `.codex\backups` 아래에 백업됩니다.

## 검증

Plugin manifest 검증:

```powershell
pwsh -NoProfile -Command "python $env:USERPROFILE\.codex\skills\.system\plugin-creator\scripts\validate_plugin.py plugins\dotnet-harness"
```

Task agents/harness 검증:

```powershell
pwsh -NoProfile -File plugins\dotnet-harness\assets\harness\.codex\scripts\validate-task-agents.ps1 -RepoRoot plugins\dotnet-harness\assets\harness
```

Skill 검증:

```powershell
pwsh -NoProfile -Command "$env:PYTHONUTF8='1'; python $env:USERPROFILE\.codex\skills\.system\skill-creator\scripts\quick_validate.py plugins\dotnet-harness\skills\<skill-name>"
```

## 관리 원칙

- plugin skill 원본은 `plugins/dotnet-harness/skills` 하나만 유지합니다.
- 설치 대상 프로젝트용 agents/scripts/AGENTS는 `plugins/dotnet-harness/assets/harness`에 둡니다.
- 현재 repo root에는 중복 `.codex` skill/agent/script 원본을 두지 않습니다.
- version 변경 시 `plugin.json`과 `VERSION.md`를 같이 갱신합니다.
- 기존 파일을 덮어쓰는 upgrade는 항상 백업을 먼저 남깁니다.

공유 주소: https://github.com/Landaq/dotnet-harness
