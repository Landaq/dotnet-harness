# Codex CLI 프로젝트 환경 적용 안내

이 문서는 현재 프로젝트 루트에 적용된 **.NET Aspire + ASP.NET Core + Blazor Auto Rendering + YARP + MSA-ready Hybrid Services + Clean Architecture + DDD + TDD** 기준 Codex CLI 구성의 사용 방법을 설명합니다. 현재 구성은 Codex를 단순 코드 생성기가 아니라, 프로젝트 구조·테스트·아키텍처 규칙을 함께 관리하는 코딩 보조 에이전트로 활용하기 위한 기본 뼈대입니다.

## 적용된 구성 요약

| 경로 | 역할 |
| --- | --- |
| `AGENTS.md` | Codex가 이 저장소에서 따라야 할 프로젝트 구조, TDD, Clean Architecture, DDD, 빌드·테스트 규칙을 정의합니다. |
| `.codex/config.toml` | 프로젝트 단위 Codex CLI 설정, 승인 정책, 샌드박스 정책, MCP 서버 예시를 담습니다. |
| `.codex/hooks.json` | Codex 작업 전후로 실행할 훅 연결 지점을 정의합니다. Windows 사용을 고려해 상대 경로 기반 Python 실행으로 조정했습니다. |
| `.codex/hooks/` | 위험 명령 감지, 작업 후 리뷰, 종료 요약을 위한 훅 스크립트를 보관합니다. |
| `.codex/rules/default.rules` | 금지 명령, EF Core 위험 명령, 테스트·빌드 허용 정책, Docker volume 삭제 확인 정책을 정의합니다. |
| `.codex/agents/` | 아키텍트, EF Core 리뷰어, 보안 리뷰어, 테스트 작성자 등 역할별 서브에이전트 템플릿을 보관합니다. |
| `.agents/skills/` | API 설계, EF Core 마이그레이션 검토, Blazor 검토, 테스트 생성, Aspire 하이브리드 서비스 작업 등 반복 작업용 스킬을 보관합니다. |
| `docs/architecture/PROJECT_STRUCTURE.md` | 목표 프로젝트 구조와 각 영역의 책임을 설명합니다. |
| `docs/architecture/SERVICE_TEMPLATE.md` | 새 백엔드 서비스를 만들 때 따를 DDD/Clean Architecture 템플릿입니다. |
| `docs/testing/TDD_GUIDE.md` | TDD 개발 순서와 테스트 계층 기준을 설명합니다. |

## 목표 프로젝트 구조

현재 프로젝트의 기준 구조는 다음과 같습니다.

```text
src/
  Aspire/
    AppHost/
    ServiceDefaults/
  FrontEnd/
    Web/
    Web.Client/
  BackEnd/
    APIGateway/
    BuildingBlocks/
      Contracts/
      Messaging/
      Observability/
    Services/
      {ServiceName}/
test/
  Architecture/
  Unit/Services/{ServiceName}/
  Integration/Services/{ServiceName}/
  Contract/Services/{ServiceName}/
  Functional/APIGateway/
  Functional/FrontEnd/
  EndToEnd/
```

| 영역 | 책임 |
| --- | --- |
| `src/Aspire/AppHost` | Aspire 분산 애플리케이션 실행 구성과 리소스 연결을 담당합니다. |
| `src/Aspire/ServiceDefaults` | 공통 Health Check, OpenTelemetry, Service Discovery, resilience 설정을 담당합니다. |
| `src/FrontEnd/Web` | Blazor Web App 서버 호스트, 인증, 라우팅, 서버 전용 서비스를 담당합니다. |
| `src/FrontEnd/Web.Client` | Auto Rendering 기준 클라이언트 실행 가능 컴포넌트를 담당합니다. |
| `src/BackEnd/APIGateway` | YARP 기반 라우팅, transform, 인증 위임, 공통 헤더 처리를 담당합니다. |
| `src/BackEnd/BuildingBlocks` | 서비스 간 최소 공통 계약·메시징·관측성 추상화를 담당합니다. |
| `src/BackEnd/Services/{ServiceName}` | MSA 전환 가능한 업무 서비스의 Domain, Application, Infrastructure, Api, Contracts 경계를 담당합니다. |
| `test` | Unit, Integration, Contract, Functional, Architecture, EndToEnd 테스트를 담당합니다. |

## 바로 사용하는 방법

프로젝트 루트에서 Codex CLI를 실행한 뒤, 다음과 같은 방식으로 요청하면 됩니다. Codex는 루트의 `AGENTS.md`를 우선 읽고, 필요에 따라 `.codex/`, `.agents/`, `docs/` 하위 지침을 참조하도록 구성되어 있습니다.

```text
AGENTS.md와 docs/architecture/PROJECT_STRUCTURE.md를 읽고 이 프로젝트의 목표 구조를 요약해줘.
```

```text
aspire-modular-ddd 스킬 기준으로 Orders 서비스를 추가하기 위한 TDD 작업 계획을 먼저 작성해줘.
```

```text
Orders 서비스의 주문 생성 유스케이스를 Red-Green-Refactor 방식으로 진행해줘. 먼저 Domain/Application 실패 테스트부터 작성해줘.
```

```text
dotnet-architect 관점으로 현재 변경사항이 Clean Architecture 의존성 방향과 서비스 경계를 지키는지 검토해줘.
```

```text
efcore-migration-review 기준으로 이번 EF Core 마이그레이션이 안전한지 검토해줘. 데이터 손실 가능성과 롤백 전략도 확인해줘.
```

## 권장 첫 실행 절차

| 단계 | 명령 또는 작업 | 목적 |
| --- | --- | --- |
| 1 | `codex` | 프로젝트 루트에서 Codex CLI를 시작합니다. |
| 2 | `AGENTS.md를 읽고 이 프로젝트의 작업 규칙을 요약해줘` | Codex가 프로젝트 지침을 정확히 인식하는지 확인합니다. |
| 3 | `docs/architecture/PROJECT_STRUCTURE.md와 SERVICE_TEMPLATE.md를 기준으로 솔루션 생성 계획을 세워줘` | 실제 `Rev04.slnx`와 `.csproj` 생성 전에 구조를 확정합니다. |
| 4 | `TDD_GUIDE.md 기준으로 테스트 프로젝트 구조를 먼저 제안해줘` | 구현보다 테스트 구조를 먼저 고정합니다. |
| 5 | `첫 번째 서비스 후보를 정하고 Domain/Application 테스트부터 작성해줘` | TDD 흐름으로 기능 개발을 시작합니다. |

## 새 서비스 작업 프롬프트 예시

아래 예시는 Codex에게 기능을 맡길 때 사용할 수 있는 기본 프롬프트입니다.

```text
{ServiceName} 서비스를 추가하려고 해.
AGENTS.md, docs/architecture/SERVICE_TEMPLATE.md, docs/testing/TDD_GUIDE.md, aspire-modular-ddd 스킬을 기준으로 진행해줘.
먼저 서비스 경계와 테스트 계획을 제안하고, Domain/Application 실패 테스트를 작성한 뒤 최소 구현을 진행해줘.
외부 공개 타입은 {ServiceName}.Contracts에 두고, Gateway, FrontEnd, Aspire 연결은 별도 단계로 나눠줘.
```

## 현재 프로젝트에 맞춰 추가로 조정할 항목

현재 루트에 실제 `.csproj` 파일이 아직 없거나 확인되지 않은 상태라면, 다음 항목은 실제 소스가 추가된 뒤 갱신하는 것이 좋습니다. 특히 `AGENTS.md`의 빌드·테스트 명령은 템플릿 기본값이므로, 실제 솔루션 이름과 테스트 프로젝트 이름에 맞춰 고정해야 합니다. 기준 솔루션 파일은 **`Rev04.slnx`**입니다.

| 조정 항목 | 예시 |
| --- | --- |
| 솔루션 빌드 명령 | `dotnet build ./Rev04.slnx -c Release` |
| 전체 테스트 명령 | `dotnet test ./Rev04.slnx -c Release` |
| AppHost 프로젝트 | `src/Aspire/AppHost/Rev04.AppHost.csproj` |
| ServiceDefaults 프로젝트 | `src/Aspire/ServiceDefaults/Rev04.ServiceDefaults.csproj` |
| Blazor Web 프로젝트 | `src/FrontEnd/Web/Rev04.Web.csproj` |
| Blazor Client 프로젝트 | `src/FrontEnd/Web.Client/Rev04.Web.Client.csproj` |
| Gateway 프로젝트 | `src/BackEnd/APIGateway/Rev04.APIGateway.csproj` |
| 서비스 프로젝트 | `src/BackEnd/Services/{ServiceName}/{ServiceName}.*/*.csproj` |

## Windows 사용 시 주의사항

`.codex/hooks.json`은 현재 다음과 같이 `python` 명령을 사용하도록 조정되어 있습니다.

```json
"command": "python \".codex/hooks/pre_tool_use_policy.py\""
```

Windows에서 `python` 명령이 동작하지 않는 경우에는 `py -3` 또는 실제 Python 실행 파일 경로로 변경하면 됩니다. Codex CLI를 WSL에서 실행한다면 `python3`로 되돌리는 편이 자연스럽습니다.

## 다음 추천 작업

이 구성이 적용된 뒤 가장 먼저 할 일은 **실제 .NET 솔루션과 프로젝트 파일을 이 구조에 맞게 생성하는 것**입니다. 그 다음에는 `test/Architecture`에서 계층 의존성 규칙을 검증하고, 첫 번째 서비스 후보를 선택해 Domain/Application 테스트부터 작성하는 흐름을 권장합니다.
