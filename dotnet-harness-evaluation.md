# dotnet-harness 냉정 평가 및 보완 계획

작성일: 2026-06-14
평가 대상: `plugins/dotnet-harness` v0.4.14
평가 방식: gpt-5.5 xhigh subagent 평가 + 로컬 소스 검토

## 0. 보완 반영 상태

2026-06-14 기준으로 다음 보완을 반영했다.

- release validation에 실제 scaffold smoke를 추가했다.
- smoke matrix는 no service, with service, harness-only, upgrade preview/apply를 포함한다.
- no service / with service scaffold는 생성 직후 `dotnet restore`, `dotnet build`, `dotnet test`를 수행한다.
- package version table을 `project-structure-setup/references/package-versions.json`으로 분리했다.
- bootstrap은 `Directory.Packages.props`를 package manifest에서 생성한다.
- non-interactive no-service automation을 위해 `--no-service` / `-NoService` 경로를 추가했다.
- task-agents 정책은 Socratic clarification first, ambiguity recalculation, runtime delegation permission gate 방향으로 정렬했다.

남은 주요 과제는 validator fixture 기반 실패 테스트와 더 깊은 behavior 중심 validator 전환이다.

## 1. 결론

**등급: B / 82점**

`dotnet-harness`는 Codex용 .NET 작업 환경을 플러그인으로 관리하려는 목적에는 꽤 잘 맞춰져 있다. 특히 task-agents 정책, harness upgrade, release validation, TaskResult opt-in, repo-local skill 중복 제거 방향은 명확하다.

하지만 현재 상태는 "정책 문서와 패키징은 강한데, 실제 scaffold 산출물과 subagent 실행 현실을 끝까지 보증하는 단계는 부족한" 구조다. 플러그인의 신뢰도를 한 단계 올리려면 문구 정리보다 **release 시 실제 생성 프로젝트를 빌드/테스트하는 검증**이 먼저 필요하다.

## 2. 강점

- `task-agents`가 agent-assisted가 아니라 agent-first orchestration 방향으로 정리되어 있다.
- non-trivial 작업에서 subagent/parallel routing을 기본값으로 둔 점은 사용자 의도와 맞다.
- `SKILL.md`는 진입점, `references/*.md`는 상세 정책으로 나눈 구조가 유지보수에 좋다.
- repo-local `.codex/skills` 복사를 중단하고 plugin skill을 source of truth로 둔 방향이 맞다.
- `upgrade-harness.ps1`가 agents/scripts 갱신, `.gitignore`, `.gitattributes`, `harness-config.json`, 백업을 다루는 점은 실사용 업그레이드에 유리하다.
- `validate-release.ps1`가 manifest, skill validation, harness validation, version consistency, packaging hygiene, whitespace까지 넓게 본다.
- TaskResult는 opt-in으로 유지되어 불필요한 산출물 생성을 피한다.

## 3. 핵심 약점

### 3.1 Subagent 정책과 실제 실행 도구의 간극

현재 문서는 non-trivial 작업에서 실제 subagent tool-call receipt를 요구한다. 방향은 좋지만, 실행 환경에 해당 subagent runner가 없거나 tool namespace가 다르면 메인 스레드가 계속 fallback하게 된다.

보완 필요:
- subagent 사용 가능 여부를 판정하는 절차를 명시해야 한다.
- unavailable fallback 기준을 문서화해야 한다.
- 최종 보고에 fallback 이유를 강제하는 수준을 넘어서, 검증 스크립트가 최소한 정책 문구와 agent metadata를 함께 확인해야 한다.

### 3.2 Release validation이 실제 scaffold build를 보증하지 않음

현재 release gate는 넓지만, 임시 프로젝트를 생성해서 `dotnet restore`, `dotnet build`, `dotnet test`까지 통과시키는 smoke 검증이 핵심 gate로 들어가 있지 않다.

이 플러그인의 가장 중요한 약속은 "설치 직후 .NET 10 Aspire/Clean Architecture scaffold가 동작한다"는 것이다. 따라서 문서/manifest 검증보다 생성 산출물 빌드 검증이 더 중요하다.

### 3.3 Validator가 아직 문구 고착 위험을 가진다

semantic token-pattern 검증이 들어간 것은 개선이지만, 일부 검증은 여전히 특정 문구 존재를 강하게 요구한다. 특히 깨진 backtick 문구까지 validator가 요구하면 문서 품질 오류가 release gate에 의해 고착될 수 있다.

즉, validator가 "품질을 보장"하는 동시에 "오탈자를 표준으로 만드는" 위험이 있다.

### 3.4 Scaffold stack/version drift 위험

`bootstrap_project_structure.py`에는 package version과 stack 구성이 강하게 박혀 있다. 현재는 사용자가 옵션 없는 고정 stack을 원했기 때문에 맞는 선택이지만, .NET 10, Aspire, MudBlazor, Scalar, YARP 버전은 drift가 빠르다.

보완 필요:
- package version table을 별도 manifest로 분리한다.
- release validation에서 실제 restore를 수행한다.
- version bump 시 package restore 결과를 release note와 함께 남긴다.

### 3.5 Baseline test coverage가 stack 약속보다 얕음

생성 solution은 Unit, Architecture, APIGateway Functional 중심으로 기본 포함된다. 하지만 플러그인은 full-stack harness를 표방한다.

보완 필요:
- 최소 smoke test 범위를 API, Gateway, Web, AppHost 중 어디까지 보증할지 명확히 나눈다.
- 처음부터 모든 테스트를 무겁게 만들 필요는 없지만, release gate에는 generated solution build/test가 반드시 들어가야 한다.

### 3.6 Workflow가 무거워질 수 있음

Socratic clarification, ambiguity scoring, phase handoff, subagent contracts, final reporting은 큰 작업에는 좋다. 하지만 작은 변경에는 과하다.

현재 lightweight/standard/deep 모드가 있더라도, 실제 사용자가 느끼는 기본 경험은 "너무 절차적"일 수 있다.

보완 필요:
- trivial one-file fix의 direct-main 허용 기준을 더 짧고 명확하게 유지한다.
- final report는 agent-first 증거만 남기고 중간 로그는 줄인다.

## 4. 우선순위 보완 계획

### P0: 다음 릴리즈 전 필수

1. 깨진 policy 문구 정리
   - `Workers`, `Git`, `TaskResult` 관련 깨진 backtick 문구를 정상화한다.
   - `validate-release.ps1`도 깨진 문구가 아니라 정상 문구를 요구하도록 수정한다.

2. release scaffold smoke 추가
   - temp directory 생성
   - 기본 scaffold 실행
   - `ServiceName` 포함 scaffold 실행
   - `--harness-only` 실행
   - upgrade preview/apply 실행
   - 생성 직후 `dotnet restore`, `dotnet build`, 가능하면 `dotnet test` 실행

   상태: 반영 완료.

3. subagent availability/fallback 정책 명확화
   - subagent runner가 있는 경우: agent-first handoff 필수
   - subagent runner가 없는 경우: fallback 허용, 최종 보고에 이유 명시
   - 사용자가 "에이전트 쓰지마"라고 한 경우: direct-main 허용

   상태: Socratic clarification first 및 runtime delegation permission gate로 반영 완료.

4. release validation 실패 케이스 fixture 추가
   - 중복 agent name
   - repo-local `.codex/skills` 존재
   - 필수 agent 누락
   - 깨진 task-agents policy 문구
   - version mismatch

   상태: 일부는 기존 validator가 확인하지만, fixture 기반 negative test는 아직 미완료.

### P1: 단기 안정화

1. scaffold test matrix 확장
   - no service
   - with service
   - existing `.gitignore`/`.gitattributes` no-overwrite
   - existing `.codex/skills` backup/remove
   - existing `.codex/harness-config.json` no-overwrite

2. package version manifest 분리
   - `bootstrap_project_structure.py`에서 version literal을 줄인다.
   - package set을 별도 JSON/props/table로 관리한다.
   - release마다 restore 결과를 확인한다.

   상태: manifest 분리 및 release smoke restore 검증 반영 완료.

3. validator를 behavior 중심으로 보강
   - 단순 문자열 존재 확인을 줄인다.
   - policy metadata, TOML field, generated output shape, duplicate discovery 결과를 확인한다.

4. worker agent 병렬화 정책 구체화
   - backend worker
   - frontend worker
   - test/verification worker
   - docs/config worker
   - 순차 의존성이 있는 경우 handoff 순서 명시

### P2: 중기 제품화

1. `harness-config.json` 확장
   - ui profile
   - package profile
   - validation profile
   - agent strictness profile
   - TaskResult preference

2. release checklist 문서화
   - version bump
   - release notes
   - generated app smoke
   - marketplace publish
   - plugin upgrade verification
   - repo-local harness upgrade verification

3. cross-platform 실행 경로 정리
   - PowerShell 중심은 유지하되, non-Windows 사용자가 어디서 막히는지 문서화한다.
   - Python helper는 UTF-8/working directory/repo detection을 명확히 처리한다.

4. agent runtime summary 표준화
   - used agents
   - skipped agents and reasons
   - fallback 여부
   - verification commands
   - rejected agent suggestions

## 5. 권장 검증 매트릭스

| 검증 | 목적 | 기대 결과 |
| --- | --- | --- |
| plugin manifest validation | plugin 구조 검증 | pass |
| quick_validate for each skill | skill metadata 검증 | pass |
| validate-task-agents.ps1 | agent/task policy 검증 | pass |
| validate-release.ps1 | release gate | pass |
| temp scaffold without service | 기본 생성 검증 | restore/build pass |
| temp scaffold with service | 서비스 포함 생성 검증 | restore/build/test pass |
| harness-only install | Codex harness만 설치 | .NET skeleton 미생성 |
| upgrade preview | 기존 repo 영향 확인 | create/remove/replace 예정 표시 |
| upgrade apply | 실제 upgrade 검증 | skills 제거, agents/scripts 교체, config 생성 |
| duplicate agent scan | Codex warning 방지 | duplicate name 없음 |

## 6. 지금 하지 말아야 할 것

- vertical/simple template을 먼저 추가하지 않는다. release smoke가 안정된 뒤 추가해야 한다.
- subagent 정책을 약하게 되돌리지 않는다. 대신 unavailable fallback을 명확히 한다.
- repo-local `.codex/skills` 복사를 되살리지 않는다. 중복 discovery 문제를 다시 만든다.
- 모든 stack을 옵션화하지 않는다. 현재 제품 목적은 옵션 많은 generator가 아니라 고정 .NET harness다.
- TaskResult를 기본 생성으로 바꾸지 않는다. 현재 repo에서는 산출물 생성이 부담이다.

## 7. 다음 실행 순서

1. 문서와 validator의 깨진 backtick 문구를 수정한다.
2. `validate-release.ps1`에 scaffold smoke를 추가한다.
3. generated solution `restore/build/test`를 release 필수 조건으로 승격한다.
4. subagent availability/fallback 판정 규칙을 task-agents 문서에 추가한다.
5. validator fixture 기반 실패 테스트를 추가한다.
6. package version manifest 분리를 설계한다.
7. worker agent 병렬화 정책을 backend/frontend/test/docs-config 단위로 나눈다.

## 8. 최종 평가

`dotnet-harness`는 방향성이 좋은 플러그인이다. 특히 사용자의 반복 요구를 plugin source of truth, upgrade script, task-agent policy, release gate로 흡수한 점은 강하다.

다만 지금 가장 큰 리스크는 "정책은 강하지만 실제 산출물 보증이 부족한 것"이다. 다음 개선의 중심은 더 많은 문서가 아니라 **생성된 프로젝트가 매번 빌드되는지 자동으로 증명하는 release gate**여야 한다.
