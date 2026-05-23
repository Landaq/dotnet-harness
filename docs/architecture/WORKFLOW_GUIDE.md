# Codex Agent Workflow Guide

## 문서 목적

이 문서는 Rev04 저장소에서 Codex 에이전트가 기능 추가, 리팩토링, 백엔드 수정, 프론트엔드 수정 작업을 수행할 때 따라야 하는 **작업 방식별 표준 워크플로**를 정의한다. Rev04는 `.NET Aspire` 기반 ASP.NET Core 풀스택 솔루션이며, 기준 솔루션 파일은 **`Rev04.slnx`**이다. Codex는 이 문서의 워크플로를 `AGENTS.md`, `.codex/rules/default.rules`, `.codex/agents/*.toml`의 저장소 규칙과 함께 적용한다.

> **핵심 원칙**: Codex는 요구사항이 충분히 명확해지기 전에는 구현을 시작하지 않는다. 작업 유형별 모호도 임계값을 만족한 뒤 스펙 파일을 만들고, 스펙 산정 후 사용자 검토 승인을 받은 다음 코드 구성을 진행한다.

## 작업 방식 분류

사용자 요청은 작업 범위와 영향 레이어에 따라 다음 세 가지 방식 중 하나로 분류한다. 분류가 모호하면 Codex는 먼저 소크라테스식 질문으로 범위를 좁힌다.

| 작업 방식 | 적용 대상 | 모호도 임계값 | 대표 에이전트 조합 | 기본 검증 관점 |
| --- | --- | ---: | --- | --- |
| 복잡한 작업 | 풀스택 기능 추가, 다중 서비스 변경, 구조 리팩토링, 아키텍처 전환, Gateway·BackEnd·FrontEnd를 함께 건드리는 작업 | **13% 이하** | `workflow-orchestrator`, `dotnet-architect`, `test-writer`, 필요 시 `frontend-agent`, `security-reviewer` | 서비스 경계, TDD 계획, API 계약, UI/API 흐름, Aspire 실행 관계 |
| 백엔드 작업 | `src/BackEnd`, `src/Aspire`, `APIGateway`, EF Core, MS SQL Server, Minimal API 중심의 간소한 수정·추가 | **5% 이하** | `workflow-orchestrator`, `dotnet-architect`, `aspnetcore-api-reviewer`, `efcore-reviewer`, `test-writer` | Domain/Application 규칙, EF Core 영향, Gateway route, 계약 테스트, 보안 |
| 프론트엔드 작업 | `src/FrontEnd/Web`, `src/FrontEnd/Web.Client`, Blazor, MudBlazor, DevExpress BI 대비 중심의 간소한 수정·추가 | **5% 이하** | `workflow-orchestrator`, `frontend-agent`, `test-writer`, 필요 시 `security-reviewer` | Auto Rendering, 브라우저 안전성, MudBlazor 우선, DevExpress 23.2 BI 기준, API 계약 |

## 모호도 산정 규칙

모호도는 Codex가 임의로 추론해야 하는 정보의 비율을 백분율로 표현한다. 모호도는 정밀한 통계값이 아니라, 구현 전 판단 기준으로 사용하는 **운영 지표**이다. Codex는 질문을 할 때마다 현재 모호도를 표시하고, 사용자의 답변을 받은 뒤 반드시 다시 계산한다.

| 평가 항목 | 확인 내용 | 모호도 증가 요인 |
| --- | --- | --- |
| 목표 명확성 | 사용자가 원하는 결과가 기능, 화면, API, 데이터 관점에서 설명되었는가 | 결과물의 성공 기준이 불명확함 |
| 범위 명확성 | 변경 대상 서비스, 프로젝트, 레이어, 파일 범위가 식별되었는가 | BackEnd/FrontEnd/Gateway/Aspire 영향 범위 불명확 |
| 데이터·계약 | DTO, API 계약, DB schema, validation, migration 필요성이 명확한가 | 계약 변경과 데이터 호환성 불명확 |
| UI·UX | 화면 흐름, 컴포넌트 라이브러리, 상태 처리, 권한 표시가 명확한가 | MudBlazor와 DevExpress 적용 기준 혼재 |
| 테스트·검증 | Red-Green-Refactor 테스트 계획과 검증 명령이 명확한가 | 실패 테스트·대상 테스트 프로젝트 불명확 |
| 운영·보안 | 인증, 인가, 비밀 정보, destructive action, 배포 영향이 확인되었는가 | 민감 정보·운영 DB·파괴적 명령 영향 불명확 |

## 소크라테스식 질문 규칙

Codex는 구현 전 요구사항을 직접 확정하지 않고, 사용자가 스스로 선택 기준을 명확히 할 수 있도록 질문한다. 모든 질문은 다음 형식을 따른다.

| 규칙 | 내용 |
| --- | --- |
| 질문 수 제한 | 한 번에 최대 **3개 안건**만 질문한다. 각 안건은 `1.`, `2.`, `3.`으로 넘버링한다. |
| 추천안 표시 | Codex가 권장하는 선택지는 반드시 **`(추천)`**으로 표시한다. |
| 모호도 표시 | 질문 전후에 현재 모호도와 목표 임계값을 함께 표시한다. |
| 재계산 의무 | 사용자가 답변할 때마다 모호도를 다시 산정하고, 임계값 충족 여부를 밝힌다. |
| 구현 보류 | 모호도가 임계값을 초과하면 구현 대신 추가 질문 또는 계획 보완을 수행한다. |

질문 예시는 다음과 같은 형태를 사용한다.

```markdown
현재 모호도는 약 18%이며, 복잡한 작업 기준 목표는 13% 이하입니다. 다음 3가지만 확인되면 스펙 산정 단계로 내려갈 수 있습니다.

1. 대상 서비스 경계는 `Orders`로 새로 만들까요, 기존 서비스에 포함할까요? `Orders` 신규 서비스 생성(추천) / 기존 서비스 확장
2. API 계약은 Gateway 외부 공개 계약까지 포함할까요? 외부 공개 계약 포함(추천) / 내부 API만 작성
3. UI는 목록·상세·생성 화면까지 포함할까요? 목록과 상세 우선(추천) / 전체 CRUD 포함
```

## 공통 워크플로

세 가지 작업 방식은 모두 다음 순서를 따른다. 단, 사용자가 기존 plan 파일을 명시하면 **코드 구성 단계부터 바로 진행**한다. 이때도 destructive action, 민감 정보, 운영 DB 영향, 커밋·푸시는 별도 승인을 요구한다.

| 순서 | 단계 | 필수 산출물 또는 확인 사항 |
| ---: | --- | --- |
| 1 | 요청사항 구체화 | 작업 방식 분류, 모호도 산정, 최대 3개 안건 질문, 임계값 충족 확인 |
| 2 | Git 브랜치 생성 및 worktree 분리 | 사용자 승인이 필요한 경우 승인 후 별도 worktree 생성. 브랜치명은 `codex/{yyMMdd}-{summary}` 형식을 우선한다. |
| 3 | 계획 수립 | 대상 프로젝트, 레이어, 파일, 테스트, 위험, 검증 명령 정의 |
| 4 | 스펙 산정 | `docs/wkTask/Specs/{yyMMdd}_{Summary}_plan.md` 작성 |
| 5 | 사용자 검토 승인 | 스펙 파일 내용을 요약하고 사용자 승인 전 구현 금지 |
| 6 | 코드 구성 | TDD 우선으로 테스트 작성 또는 테스트 계획 반영 후 최소 구현 |
| 7 | 리뷰 및 피드백 | 아키텍처, 보안, 테스트, UI, API 계약 관점의 자체 리뷰 수행 |
| 8 | 피드백 반영 | 리뷰 결과에 따라 코드와 문서를 보정 |
| 9 | Git 머지 후 병합 worktree 제거 | 커밋, 푸시, 머지, worktree 제거는 사용자 명시 승인 후 수행 |
| 10 | 결과 HTML 생성 | `docs/wkTask/Results/{yyMMdd}_{Summary}_result.html` 작성 |

## 스펙 파일 규칙

스펙 파일은 구현 전에 요구사항, 작업 범위, 테스트 전략, 위험, 승인 상태를 고정하는 계약 문서이다. 파일명은 `docs/wkTask/Specs/{yyMMdd}_{Summary}_plan.md` 형식을 사용한다. `{Summary}`는 영문 또는 안전한 ASCII kebab/pascal 요약을 사용하고, 공백은 `_` 또는 `-`로 치환한다.

스펙 파일에는 다음 섹션을 포함한다.

| 섹션 | 필수 내용 |
| --- | --- |
| 작업 개요 | 사용자 요청, 작업 방식, 모호도, 목표 임계값, 승인 상태 |
| 범위 | 포함 범위와 제외 범위, 영향 프로젝트, 영향 레이어 |
| 아키텍처 계획 | 서비스 경계, Clean Architecture 의존성, Gateway/Aspire/FrontEnd 영향 |
| TDD 계획 | Red-Green-Refactor 순서, 테스트 프로젝트, 테스트 케이스 목록 |
| 구현 계획 | 변경 파일 후보, 작업 순서, 데이터·계약 변경 사항 |
| 검증 계획 | `dotnet restore ./Rev04.slnx`, `dotnet build ./Rev04.slnx --no-restore`, `dotnet test ./Rev04.slnx --no-build` 또는 범위 축소 명령 |
| 위험 및 승인 필요 항목 | 민감 정보, 마이그레이션, destructive action, 커밋·푸시·머지 필요 여부 |
| 사용자 승인 기록 | 승인 일시, 승인 문구, 변경된 요구사항 |

## 결과 HTML 규칙

결과 파일은 작업 종료 후 수행 결과를 사람이 읽기 쉽게 정리하는 보고서이다. 파일명은 `docs/wkTask/Results/{yyMMdd}_{Summary}_result.html` 형식을 사용한다. 결과 HTML에는 최소한 작업 목표, 변경 요약, 테스트 및 검증 결과, 남은 위험, 후속 권장 사항, Git 상태를 포함한다.

결과 HTML은 민감 정보를 포함하지 않아야 하며, 연결 문자열, 토큰, 인증서, 개인 키, 실제 운영 URL, 계정 정보를 그대로 노출하지 않는다. 필요한 경우 placeholder로 표현한다.

## 작업 방식별 상세 지침

### 복잡한 작업

복잡한 작업은 여러 레이어나 서비스에 영향을 주므로, 모호도 **13% 이하**가 될 때까지 구체화한다. Codex는 도메인 경계, API 계약, UI 흐름, Gateway route, Aspire 실행 관계, 테스트 계층을 함께 검토한다. 기능 추가와 리팩토링이 동시에 포함되는 경우, 먼저 안전한 세로 슬라이스를 정의하고 이후 반복 단위로 확장한다.

| 관점 | 확인 사항 |
| --- | --- |
| 서비스 경계 | 신규 `Services/{ServiceName}` 생성인지 기존 서비스 확장인지 확인한다. |
| 계약 | `{ServiceName}.Contracts`, Gateway 공개 API, FrontEnd typed client 영향을 확인한다. |
| 테스트 | Unit, Integration, Contract, Functional, EndToEnd 중 필요한 최소 세트를 정의한다. |
| 마이그레이션 | EF Core migration 필요성과 운영 DB 영향 여부를 별도 승인 항목으로 둔다. |
| UI | MudBlazor 기본 UI와 DevExpress 23.2 BI 대비 필요성을 구분한다. |

### 백엔드 작업

백엔드 작업은 변경 범위가 상대적으로 좁더라도 데이터, 계약, 보안 영향이 크기 때문에 모호도 **5% 이하**가 될 때까지 구체화한다. Codex는 Domain/Application 규칙과 EF Core·SQL Server 영향, Minimal API endpoint, YARP route, 테스트 경계를 우선 확인한다.

| 관점 | 확인 사항 |
| --- | --- |
| Domain | 업무 규칙이 Entity, ValueObject, Domain Service 중 어디에 위치해야 하는지 확인한다. |
| Application | Command, Query, DTO, Validator, Port 인터페이스 변경을 식별한다. |
| Infrastructure | DbContext, Repository, migration, 외부 adapter 변경 필요성을 확인한다. |
| Api/Gateway | Minimal API route, response type, ProblemDetails, YARP route/cluster 영향 여부를 확인한다. |
| 검증 | 백엔드 범위 테스트와 `Rev04.slnx` 전체 검증 중 필요한 명령을 지정한다. |

### 프론트엔드 작업

프론트엔드 작업은 UI 동작과 API 계약의 작은 차이가 사용자 경험에 직접 영향을 주므로 모호도 **5% 이하**가 될 때까지 구체화한다. Codex는 Blazor Web App Auto Rendering, `Web.Client` 브라우저 안전성, MudBlazor 우선 정책, DevExpress Blazor 23.2 BI 대비 기준을 함께 확인한다.

| 관점 | 확인 사항 |
| --- | --- |
| 렌더링 | Auto Rendering, SSR, Interactive WebAssembly 경계와 서버 전용 의존성 사용 여부를 확인한다. |
| UI 라이브러리 | 일반 업무 UI는 MudBlazor를 우선하고, BI·대시보드·리포팅은 DevExpress 23.2 기준으로 분리한다. |
| API | FrontEnd가 APIGateway를 경유하는지, Contracts 또는 typed client를 통해 계약을 소비하는지 확인한다. |
| 상태와 권한 | 로딩, 오류, 권한별 표시, validation, 접근성, 반응형 동작을 정의한다. |
| 테스트 | `test/Functional/FrontEnd` 중심으로 렌더링, 폼 동작, API client interaction 테스트를 계획한다. |

## Git worktree 운영 원칙

Codex는 사용자의 명시 승인 없이 브랜치 생성, 커밋, 푸시, 머지, rebase, reset, clean, worktree 제거를 수행하지 않는다. 별도 worktree가 승인되면 기존 작업 디렉터리를 오염시키지 않기 위해 `../Rev04.worktrees/{branch-summary}` 같은 분리 경로를 우선 사용한다.

| 작업 | 승인 필요 여부 | 비고 |
| --- | --- | --- |
| 상태 확인 | 불필요 | `git status`, `git branch`, `git worktree list` 등 읽기 작업 |
| 브랜치·worktree 생성 | 필요 | 사용자에게 브랜치명과 경로를 먼저 제안한다. |
| 파일 수정 | 스펙 승인 후 수행 | plan 파일이 명시된 경우 코드 구성부터 진행 가능하다. |
| 커밋·푸시·머지 | 필요 | 커밋 메시지, 대상 브랜치, PR 영향 범위를 설명한다. |
| 삭제·초기화 | 필요 | 파일 삭제, worktree 제거, reset, clean은 파괴적 작업으로 취급한다. |

## plan 파일 언급 시 예외 흐름

사용자가 `docs/wkTask/Specs/{yyMMdd}_{Summary}_plan.md` 같은 plan 파일을 직접 언급하거나, “이 plan대로 진행”처럼 명시하면 Codex는 요구사항 구체화와 스펙 산정 단계를 반복하지 않고 **코드 구성 단계부터 바로 진행**한다. 다만 다음 항목은 계속 확인한다.

| 확인 항목 | 처리 기준 |
| --- | --- |
| plan 파일 존재 여부 | 파일을 읽고 승인 상태와 범위를 확인한다. |
| 모호도 | 기존 plan의 모호도가 임계값 이하인지 확인하고, 새로 생긴 모호함만 질문한다. |
| 승인 | plan에 승인 기록이 없으면 사용자에게 구현 승인만 별도로 요청한다. |
| 파괴적 작업 | 커밋, 푸시, 머지, 삭제, DB 변경은 별도 명시 승인 후 수행한다. |

## 민감 정보 및 안전 규칙

Codex는 워크플로 전 과정에서 민감 정보를 읽거나 출력하지 않는다. `.env`, 운영용 `appsettings.*.json`, 연결 문자열, 토큰, 인증서, 개인 키, 계정 정보, 배포 자격 증명은 응답과 문서에 포함하지 않는다. DB 변경, migration 적용, 파일 삭제, Git destructive action은 항상 사용자 승인 후 수행한다.
