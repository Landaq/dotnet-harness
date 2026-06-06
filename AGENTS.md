# AGENTS.md

이 repo는 .NET 애플리케이션 repo가 아니라 `dotnet-harness` Codex plugin 개발 repo다. 일반 코딩 원칙은 전역 `C:\Users\cwnv2002\.codex\AGENTS.md`를 따른다.

## 1. Source Of Truth

- Plugin 원본: `plugins/dotnet-harness`
- Skill 원본: `plugins/dotnet-harness/skills`
- 설치 대상 프로젝트용 harness 원본: `plugins/dotnet-harness/assets/harness`
- Marketplace: `.agents/plugins/marketplace.json`

루트 `.codex/skills`, `.codex/agents`, `.codex/scripts`는 중복 원본으로 만들지 않는다.
이 plugin 개발 repo에서는 작업 결과 HTML 파일을 생성하지 않는다.

## 2. 작업 라우팅

- 비단순 작업은 `plugins/dotnet-harness/skills/task-agents/SKILL.md`를 기준으로 진행한다.
- Project setup 변경은 `plugins/dotnet-harness/skills/project-structure-setup`을 수정한다.
- Agent 변경은 `plugins/dotnet-harness/assets/harness/.codex/agents`를 수정한다.
- Helper script 변경은 `plugins/dotnet-harness/assets/harness/.codex/scripts`를 수정한다.
- 설치 대상 프로젝트 안에서는 `.codex/agents`, `.codex/skills`, `.codex/scripts`가 사용되지만, 이 repo의 원본은 plugin 아래에만 둔다.

## 3. Dotnet Harness 계약

기본 setup은 옵션 없이 다음 기준을 설치해야 한다.

- .NET 10
- Aspire orchestration
- Clean Architecture + DDD
- ASP.NET Core Minimal API
- EF Core + SQL Server
- Redis
- YARP proxy
- Scalar UI API docs
- Blazor Auto Rendering
- MudBlazor
- mediator-like in-process dispatcher

`--harness-only`는 프로젝트 구조와 .NET skeleton을 만들지 않고 Codex harness만 설치해야 한다.

## 4. 검증

Plugin 변경 후:

```powershell
pwsh -NoProfile -Command "python C:\Users\cwnv2002\.codex\skills\.system\plugin-creator\scripts\validate_plugin.py plugins\dotnet-harness"
```

Harness/agent/script 변경 후:

```powershell
pwsh -NoProfile -File plugins/dotnet-harness/assets/harness/.codex/scripts/validate-task-agents.ps1 -RepoRoot plugins/dotnet-harness/assets/harness
```

Skill 변경 후:

```powershell
pwsh -NoProfile -Command "$env:PYTHONUTF8='1'; python C:\Users\cwnv2002\.codex\skills\.system\skill-creator\scripts\quick_validate.py plugins\dotnet-harness\skills\<skill-name>"
```

## 5. Release 규칙

- 버전 변경 시 `plugins/dotnet-harness/.codex-plugin/plugin.json`과 `plugins/dotnet-harness/VERSION.md`를 같이 수정한다.
- 이름 변경 시 `.agents/plugins/marketplace.json`, README, AGENTS 문구를 함께 확인한다.
- 기존 프로젝트 업그레이드는 `upgrade-harness.ps1 -Apply`로 백업 후 진행한다.
