# AGENTS.md

## Repository role

이 저장소에서 Codex는 **.NET Aspire 기반 ASP.NET Core 하이브리드 서비스 아키텍처 개발 보조 에이전트**로 동작한다. 주요 기술 범위는 ASP.NET Core, Minimal API, EF Core, MS SQL Server, YARP, Blazor Web App, Blazor WebAssembly, MudBlazor 기반 기본 UI, DevExpress Blazor 23.2 기준 BI UI 대비, TDD, Clean Architecture, DDD, xUnit/NUnit/MSTest 기반 테스트, Docker 기반 개발 환경을 포함한다.

Rev04의 기준 아키텍처는 순수 모듈형 모놀리스도, 처음부터 모든 기능을 독립 배포하는 순수 MSA도 아니다. 이 저장소는 **MSA-ready Hybrid Architecture**를 따른다. 각 백엔드 업무 경계는 장래 독립 서비스로 분리될 수 있는 서비스 후보로 설계하되, 초기 개발 단계에서는 단일 솔루션 안에서 테스트·빌드·실행 복잡도를 낮게 유지한다.

## General working agreements

Codex는 코드를 수정하기 전에 먼저 현재 솔루션 구조, `Rev04.slnx`, 프로젝트 파일, 테스트 명령, 실행 환경을 확인해야 한다. 사용자가 명시적으로 긴급 수정을 요청하지 않는 한, 변경 전에는 간단한 계획을 제시하고 변경 후에는 수행한 작업, 검증 결과, 남은 위험을 구분해 보고한다. 이 저장소의 기준 솔루션 파일은 `.sln`이 아니라 **`Rev04.slnx`**이며, Codex는 사용자의 명시 요청 없이 `.sln` 파일을 새 기준으로 생성하거나 문서화하지 않는다.

민감 파일과 비밀 정보는 읽거나 출력하지 않는다. `.env`, `appsettings.Production.json`, `appsettings.*.json`의 실제 연결 문자열, 인증서, 개인 키, 토큰, 사용자 비밀번호, 배포 자격 증명은 직접 열람하거나 응답에 포함하지 않는다. 설정 예시는 반드시 placeholder로 작성한다.

## Target solution structure

이 저장소의 기준 구조는 다음과 같다. 새 코드는 이 구조를 우선 따르고, 기존 구조와 충돌하는 경우 변경 전 사용자에게 조정안을 제시한다. 솔루션 항목은 `Rev04.slnx`에 추가하며, 루트 표준화 파일로 `global.json`, `Directory.Build.props`, `Directory.Packages.props`를 우선 사용한다.

```text
Rev04.slnx
global.json
Directory.Build.props
Directory.Packages.props
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

| 영역 | 책임 | Codex 작업 기준 |
| --- | --- | --- |
| `src/Aspire/AppHost` | 분산 앱 실행 모델과 리소스 연결 | 프로젝트 참조, SQL Server, Redis, Gateway, Web, 서비스 실행 관계만 작성한다. 도메인 로직을 두지 않는다. |
| `src/Aspire/ServiceDefaults` | 공통 서비스 기본값 | Health Check, OpenTelemetry, Service Discovery, resilience 설정을 관리한다. 도메인 모델, DTO, 업무 유틸리티를 넣지 않는다. |
| `src/FrontEnd/Web` | Blazor Web App 서버 호스트 | 인증, 라우팅, 서버 전용 서비스, SSR 경계를 담당한다. |
| `src/FrontEnd/Web.Client` | Blazor WebAssembly 클라이언트 | Auto Rendering 대상 컴포넌트와 클라이언트 UI를 둔다. 비밀 정보와 서버 전용 의존성을 두지 않는다. |
| `src/BackEnd/APIGateway` | YARP 기반 외부 진입점 | 라우팅, transform, 인증 위임, CORS, 공통 헤더, health check를 담당한다. 비즈니스 유스케이스를 구현하지 않는다. |
| `src/BackEnd/BuildingBlocks` | 서비스 간 최소 공통 기반 | cross-cutting contracts, messaging abstraction, observability helper만 둔다. 특정 서비스의 Domain 모델 또는 Application 유스케이스를 공유하지 않는다. |
| `src/BackEnd/Services/{ServiceName}` | MSA 전환 가능한 업무 서비스 경계 | Domain, Application, Infrastructure, Api, Contracts 경계를 유지한다. 각 서비스는 장래 독립 배포와 독립 DB 소유가 가능하도록 작성한다. |
| `test` | 테스트 코드 | Unit, Integration, Contract, Functional, Architecture, EndToEnd 테스트를 목적별로 분리한다. |

## BackEnd service architecture

각 백엔드 기능은 `src/BackEnd/Services/{ServiceName}` 아래에 배치한다. `{ServiceName}`은 업무 언어를 사용하며, `Identity`, `Orders`, `Payments`, `Inventory`처럼 독립적인 서비스 경계를 표현한다. 기술 이름이나 구현체 이름을 서비스 이름으로 사용하지 않는다.

```text
src/BackEnd/Services/{ServiceName}/
  {ServiceName}.Domain/
    Aggregates/
    Entities/
    ValueObjects/
    Events/
    Repositories/
  {ServiceName}.Application/
    Abstractions/
    UseCases/
      Commands/
      Queries/
    DTOs/
    Validators/
  {ServiceName}.Infrastructure/
    Persistence/
      Configurations/
      Migrations/
    Repositories/
    Integrations/
  {ServiceName}.Api/
    Endpoints/
    Mapping/
  {ServiceName}.Contracts/
    Requests/
    Responses/
    IntegrationEvents/
```

| 계층 | 허용 의존성 | 금지 의존성 | 핵심 규칙 |
| --- | --- | --- | --- |
| `Domain` | 없음 또는 순수 공통 추상화 | EF Core, ASP.NET Core, HTTP, DB, 외부 SDK, 다른 서비스 내부 구현 | 업무 규칙, Aggregate, Entity, ValueObject, Domain Event를 둔다. |
| `Application` | `Domain` | EF Core 구체 타입, Endpoint, 외부 SDK 직접 호출, 다른 서비스 Infrastructure | Command, Query, UseCase, Port 인터페이스, DTO, Validator를 둔다. |
| `Infrastructure` | `Application`, `Domain`, 필요한 `Contracts` | 다른 서비스 DB 직접 접근, 다른 서비스 내부 구현 | DbContext, Repository 구현, 외부 시스템 adapter를 둔다. |
| `Api` | `Application`, `Contracts` | Infrastructure 구체 구현 직접 사용, 도메인 규칙 직접 구현 | Minimal API endpoint와 mapping을 둔다. |
| `Contracts` | 없음 또는 `BuildingBlocks/Contracts` | Domain 내부 모델, Infrastructure 구현 | 외부 공개 request/response, integration event, gateway/front-end 계약을 둔다. |

Codex는 기능 추가 시 `Domain → Application → Infrastructure → Api → APIGateway → FrontEnd → Aspire` 순서로 영향 범위를 추적한다. 의존성 방향은 반대로 흐르지 않도록 관리한다. 서비스 간 연동은 다른 서비스의 내부 프로젝트를 직접 참조하지 말고, 공개 `Contracts`, HTTP API, integration event, Gateway route를 통해 표현한다.

## Hybrid service and MSA readiness rules

이 저장소의 서비스는 초기에는 하나의 솔루션에서 함께 개발될 수 있지만, 다음 규칙을 지켜야 한다.

| 규칙 | 설명 |
| --- | --- |
| 독립 경계 | 각 서비스는 하나의 bounded context 후보로 다루며 자체 Domain/Application/Infrastructure/Api/Contracts 경계를 가진다. |
| 독립 데이터 소유 | 장기적으로 서비스별 DB 또는 schema 분리가 가능하도록 설계한다. 한 서비스가 다른 서비스의 테이블을 직접 읽거나 쓰지 않는다. |
| 공개 계약 우선 | 서비스 외부로 노출되는 타입은 `{ServiceName}.Contracts`에 두고 Domain 모델을 외부 계약으로 직접 노출하지 않는다. |
| 분산 전환 가능성 | 서비스 경계가 안정되면 Aspire AppHost에서 개별 실행 프로젝트로 등록하고 YARP route/cluster로 외부 경로를 연결할 수 있게 한다. |
| 복잡도 지연 | 메시징, 독립 배포, 서비스별 DB 분리는 필요가 확정될 때 단계적으로 도입한다. |

## TDD working rule

이 저장소는 **TDD 우선**을 기본 개발 방식으로 사용한다. 기능 구현을 요청받으면 Codex는 즉시 구현하지 말고 먼저 테스트 계획을 제시한 뒤, 가능한 경우 실패 테스트를 작성하고 최소 구현을 진행한다.

| 단계 | Codex가 해야 할 일 |
| --- | --- |
| Red | 요구사항을 Domain 또는 Application 테스트로 표현한다. |
| Green | 테스트를 통과하는 최소 구현을 작성한다. |
| Refactor | Clean Architecture, DDD, 네이밍, 중복 제거, 서비스 경계와 의존성 규칙을 정리한다. |

테스트 구조는 다음을 따른다.

```text
test/
  Architecture/
  Unit/Services/{ServiceName}/
  Integration/Services/{ServiceName}/
  Contract/Services/{ServiceName}/
  Functional/APIGateway/
  Functional/FrontEnd/
  EndToEnd/
```

## Build and validation commands

저장소 구조를 먼저 확인한 뒤 가장 적절한 명령을 선택한다. 일반적인 .NET 솔루션에서는 다음 순서를 기본 검증 흐름으로 사용한다.

```bash
dotnet restore ./Rev04.slnx
dotnet build ./Rev04.slnx --no-restore
dotnet test ./Rev04.slnx --no-build
```

포맷 검사가 필요한 경우 다음 명령을 사용한다.

```bash
dotnet format --verify-no-changes
```

특정 프로젝트만 검증할 때는 솔루션 전체 명령보다 해당 `.csproj` 또는 테스트 프로젝트를 대상으로 실행한다. 테스트가 실패하면 실패한 테스트명, 실패 원인 추정, 관련 파일, 재현 명령을 함께 보고한다.

## ASP.NET Core and Minimal API conventions

Minimal API 엔드포인트는 서비스 단위로 그룹화하고, 라우트 정의, 요청 DTO, 응답 DTO, 유효성 검증, 인증/인가 정책을 명확히 분리한다. 엔드포인트는 가능한 경우 `Results<Ok<T>, BadRequest<ProblemDetails>, NotFound>`처럼 명시적 결과 타입을 사용한다.

컨트롤러 기반 API가 이미 존재하는 프로젝트에서는 기존 패턴을 우선한다. Minimal API와 Controller를 혼합할 때는 라우팅, OpenAPI 문서화, 인증 정책이 중복되거나 충돌하지 않도록 검토한다.

## EF Core and SQL Server conventions

EF Core 변경 시에는 엔티티, `DbContext`, Fluent API 구성, 마이그레이션, 쿼리 성능을 함께 검토한다. 마이그레이션 파일은 자동 생성 결과를 그대로 신뢰하지 말고, 데이터 손실 가능성, 인덱스 변경, nullable 변경, cascade delete, default value, computed column, SQL Server 호환성을 확인한다.

운영 데이터에 영향을 줄 수 있는 명령은 실행하지 않는다. 특히 `dotnet ef database update`, `dotnet ef database drop`, 직접 SQL DELETE/UPDATE, 마이그레이션 롤백은 사용자의 명시 승인을 받은 뒤에만 제안하거나 실행한다.

## Blazor Auto Rendering conventions

프런트엔드는 `src/FrontEnd/Web`과 `src/FrontEnd/Web.Client`를 분리한다. 기본 방향은 **Blazor Web App의 Auto Rendering**이다. Auto Rendering 대상 페이지와 컴포넌트는 클라이언트 실행 가능성을 고려해야 하며, 브라우저에서 사용할 수 없는 서버 전용 의존성을 참조하지 않는다.

`Web.Client`에는 비밀 정보, 연결 문자열, 서버 파일 시스템 접근, 직접 DB 접근, 서버 전용 SDK를 두지 않는다. `Web`은 서버 호스트, 인증, SSR 경계, 서버 전용 서비스 연결을 담당한다. 클라이언트에서 백엔드 기능을 호출할 때는 원칙적으로 `APIGateway`를 경유한다.

기본 UI 컴포넌트 라이브러리는 **MudBlazor**로 둔다. 일반 업무 화면, 레이아웃, 내비게이션, 폼, 다이얼로그, 테이블, 검증 UI, 공통 상호작용 컴포넌트는 우선 MudBlazor로 설계한다. 대시보드, 피벗·그리드 중심 분석 화면, 리포팅, 차트 중심 분석 페이지, 내보내기 중심 데이터 뷰처럼 **BI 관련 UI 또는 기능**은 **DevExpress Blazor 23.2.x 기준**으로 대비한다. 단순 CRUD나 일반 레이아웃에는 DevExpress를 기본 도입하지 않으며, DevExpress 계열 패키지·라이선스·NuGet feed·계정 정보는 소스, `Web.Client`, `appsettings`, 문서 예시에 직접 기록하지 않는다.

## YARP conventions

YARP 설정 변경 시에는 라우트, 클러스터, transform, health check, timeout, 인증/인가 위임, 헤더 전달 정책을 함께 검토한다. 프록시 설정은 보안상 민감할 수 있으므로 공개 인터넷으로 열리는 라우트와 내부 서비스 라우트를 명확히 분리한다.

Gateway는 비즈니스 유스케이스를 구현하지 않는다. Gateway에서 처리할 수 있는 것은 라우팅, 인증 위임, 공통 헤더, correlation id, timeout, rate limiting, 관측성 설정으로 제한한다.

## Aspire conventions

`AppHost`는 프로젝트와 리소스의 실행 관계를 정의한다. `ServiceDefaults`는 공통 health check, telemetry, service discovery, resilience 설정을 제공한다. Aspire 관련 변경 시에는 각 서비스가 로컬에서 어떤 순서와 의존성으로 실행되는지 함께 설명한다.

## Security requirements

인증과 인가 변경은 가장 높은 우선순위로 검토한다. JWT, Cookie, OAuth/OIDC, API Key, CORS, CSRF, SSRF, SQL Injection, Mass Assignment, Open Redirect, deserialization 위험을 확인한다. 사용자 입력은 서버 측에서 검증해야 하며, 클라이언트 검증만으로 충분하다고 간주하지 않는다.

## Dependency policy

새 NuGet 패키지나 npm 패키지를 추가하기 전에 목적, 대안, 유지보수 상태, 보안 영향, 라이선스 영향을 설명한다. 패키지 추가 후에는 프로젝트 파일 변경과 lock 파일 변경을 함께 확인한다.

## Git and destructive action policy

Codex는 사용자의 명시 승인 없이 커밋, 푸시, rebase, force push, reset, clean, stash drop, 브랜치 삭제, 태그 삭제를 수행하지 않는다. 파일 삭제가 필요한 경우 삭제 이유와 영향 범위를 먼저 설명한다.

## Related local documents

| 문서 | 용도 |
| --- | --- |
| `CODEX_SETUP.md` | Codex CLI 적용 및 실행 안내 |
| `docs/architecture/PROJECT_STRUCTURE.md` | 전체 프로젝트 구조와 아키텍처 원칙 |
| `docs/architecture/SERVICE_TEMPLATE.md` | 새 백엔드 서비스 생성 규칙 |
| `docs/architecture/FRONTEND_UI_GUIDELINES.md` | MudBlazor 기본 UI와 DevExpress Blazor 23.2 BI 대비 기준 |
| `docs/testing/TDD_GUIDE.md` | TDD 및 테스트 계층 운영 기준 |
| `docs/architecture/REFERENCE_COMPARISON.md` | `.slnx`, Aspire, Blazor, YARP, DDD, MSA-ready 구조 외부 레퍼런스 비교 분석 |
