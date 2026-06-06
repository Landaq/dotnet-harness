# AGENTS.md

현재 repo 전용 agent/skill 라우팅 규칙. 일반 코딩 원칙은 전역 `C:\Users\cwnv2002\.codex\AGENTS.md` 따른다.

상세 routing 원본 = `.codex/skills/task-agents/SKILL.md`. Agent/skill 원본 = `.codex/agents`, `.codex/skills`.

## 1. Bootstrap

- 비단순 작업은 먼저 `.codex/skills/task-agents/SKILL.md`를 따른다.
- `.codex/agents/*.toml`과 `.codex/skills/*/SKILL.md`를 현재 repo에서 발견해 사용한다.
- project/solution/agent/skill 이름 하드코딩 금지.
- 상세 routing, 병렬 규칙, stop condition은 `task-agents`를 원본으로 삼는다.

## 2. Context7

- 외부 library/framework/API 판단이 필요하면 Context7 MCP로 최신 문서를 확인한다.
- 특히 review/audit/verification 단계에서 outdated API 추정으로 판단하지 않는다.

## 3. 프로젝트 검증

```powershell
pwsh -NoProfile -File .codex/scripts/validate-task-agents.ps1
```
