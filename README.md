# Codex Harness

현재 repo는 Codex 작업 흐름을 프로젝트 안에서 재사용하기 위한 harness입니다. 핵심은 `.codex/skills`와 `.codex/agents`에 둔 repo-local 규칙으로, 프로젝트 구조 생성, 작업 라우팅, 구현 전 검토, 테스트 전략, 리뷰, 검증을 같은 방식으로 반복 수행하게 하는 것입니다.

## 구성 요소

- `.codex/skills/project-structure-setup`: 프로젝트 기본 폴더 구조를 먼저 구성합니다.
- `.codex/skills/task-agents`: 현재 repo에서 발견한 agent와 skill을 기준으로 작업을 라우팅합니다.
- `.codex/agents`: workflow guardrail, planning, coordination, specialist review, verification, git operation 역할을 나눕니다.
- `AGENTS.md`: 이 repo에서 agent/skill을 시작할 때 따라야 할 최소 bootstrap 규칙입니다.

## 기본 수행 절차

Task Agents를 바로 실행하기 전에 먼저 프로젝트 구조를 구성해야 합니다.

1. `project-structure-setup` skill을 사용해 기본 구조를 만듭니다.
   - Aspire, FrontEnd, BackEnd, test 폴더 기준을 잡습니다.
   - `docs/Project/README.md`를 생성해 기본 구조 요약을 남깁니다.
   - 필요한 경우 service 이름을 받아 service scaffold까지 생성합니다.

2. 구조 생성 결과를 확인합니다.
   - 생성된 폴더와 `.gitkeep` 파일을 점검합니다.
   - 기존 파일을 덮어쓰거나 삭제하지 않았는지 확인합니다.

3. 그 다음 `task-agents` skill을 사용합니다.
   - `.codex/agents/*.toml`을 발견합니다.
   - `.codex/skills/*/SKILL.md`를 발견합니다.
   - solution, `src`, `test`, `docs/Project/README.md` anchor를 확인합니다.
   - 기본 구조가 없으면 경고하고 `project-structure-setup`을 먼저 수행하라고 지시합니다.

4. Task Agents 라우팅 순서에 따라 작업합니다.
   - `workflow-guardrails`: 안전/승인 gate
   - `intake-planner`: 작업 단위와 성공 기준 정리
   - `implementation-coordinator`: specialist 선택과 순서 결정
   - specialist analysis: backend, frontend, TDD, audit 분석
   - serial implementation: 파일 수정은 직렬 수행
   - `code-reviewer`: diff review
   - `verification-runner`: 최소 검증 command 실행
   - `git-operator`: 사용자가 명시 요청한 git 작업만 수행

## 검증

Task Agents 또는 agent 파일을 바꾼 뒤에는 아래 검증을 실행합니다.

```powershell
pwsh -NoProfile -File .codex/scripts/validate-task-agents.ps1
```

Skill 파일을 바꾼 뒤에는 해당 skill도 검증합니다.

```powershell
python C:\Users\cwnv2002\.codex\skills\.system\skill-creator\scripts\quick_validate.py .codex\skills\<skill-name>
```

## 원칙

- 현재 repo에서 발견한 agent/skill을 우선 사용합니다.
- 프로젝트 이름, solution 이름, agent 이름을 하드코딩하지 않습니다.
- 여러 agent가 같은 파일을 동시에 수정하지 않습니다.
- 구현은 검토와 승인 gate 이후에 수행합니다.
- 완료 주장은 실제 검증 결과로만 합니다.
