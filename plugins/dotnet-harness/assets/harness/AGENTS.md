# AGENTS.md

현재 repo 전용 agent 라우팅 규칙. 전역 AGENTS.md가 존재하면 함께 따르되, 이 파일의 repo-local 규칙을 우선 적용한다.

상세 routing 원본 = `dotnet-harness:task-agents`. Agent 원본 = `.codex/agents`. Skill 원본 = dotnet-harness plugin skills.

## 1. Bootstrap

- 비단순 작업은 먼저 `dotnet-harness:task-agents`를 따른다.
- 비단순 작업은 사용자가 에이전트를 따로 말하지 않아도 기본적으로 subagent/parallel-agent workflow를 사용한다.
- 사용자가 `에이전트 쓰지마`, `no agents`, `skip agents`, `직접 해줘`, `빠르게 메인에서 해줘`, `main thread only`처럼 명시적으로 opt-out한 경우에만 메인 직접 수행으로 전환한다.
- `.codex/agents/*.toml`을 현재 repo에서 발견하고, 필요한 skill은 `dotnet-harness:*` plugin skill을 사용한다.
- project/solution/agent/skill 이름 하드코딩 금지.
- 상세 routing, 병렬 규칙, stop condition은 `dotnet-harness:task-agents`를 원본으로 삼는다.

## 2. Context7

- 외부 library/framework/API 판단이 필요하면 Context7 MCP로 최신 문서를 확인한다.
- 특히 review/audit/verification 단계에서 outdated API 추정으로 판단하지 않는다.

## 3. 프로젝트 검증

Windows:

```powershell
pwsh -NoProfile -File .codex/scripts/validate-task-agents.ps1
```

macOS:

```zsh
./.codex/scripts/validate-task-agents.zsh --repo-root .
```
