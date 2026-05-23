# 프로젝트 구조 설계

이 문서는 Rev04 저장소에서 사용할 **.NET Aspire 기반 하이브리드 서비스 아키텍처**를 정의한다. 목표는 `Aspire AppHost`, `Blazor Web App + Web.Client`, `MudBlazor 기본 UI`, `DevExpress Blazor 23.2 기준 BI UI 대비`, `YARP API Gateway`, `MSA-ready BackEnd Services`, `TDD`, `Clean Architecture`, `DDD`를 하나의 일관된 개발 규칙으로 묶는 것이다.

> 이 저장소의 기본 방향은 **서비스 경계를 먼저 명확히 잡고, 초기에는 단일 솔루션의 개발 편의성을 유지하며, 경계가 안정된 서비스만 단계적으로 MSA로 분리할 수 있게 만드는 구조**다.

## 1. 최상위 구조

현재 프로젝트의 기준 구조는 다음과 같다.

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

`src/Aspire/AppHost`는 실행 가능한 애플리케이션들을 코드 기반으로 연결하는 로컬 오케스트레이션 진입점이다. Aspire의 AppHost는 애플리케이션 서비스와 서비스 간 관계를 코드로 선언하는 위치이며, 분산 애플리케이션의 로컬 실행 모델을 관리하는 역할을 한다.[1] 따라서 AppHost에는 `Web`, `APIGateway`, 각 백엔드 서비스, 데이터베이스, 캐시, 메시징 리소스 같은 실행 리소스 간 의존 관계만 선언하고, 도메인 로직을 두지 않는다.

| 경로 | 책임 | 포함 대상 | 제외 대상 |
| --- | --- | --- | --- |
| `src/Aspire/AppHost` | 로컬 분산 앱 실행 모델 | 프로젝트 참조, SQL Server, Redis, Gateway, Web, 서비스 연결 | 도메인 로직, API 엔드포인트 구현 |
| `src/Aspire/ServiceDefaults` | 공통 서비스 기본값 | Health Check, OpenTelemetry, Service Discovery, 공통 resilience 설정 | 특정 서비스의 비즈니스 규칙 |
| `src/FrontEnd/Web` | Blazor Web App 서버 호스트 | Razor Components 서버 호스트, 인증, BFF 성격의 서버 설정 | 복잡한 도메인 로직 |
| `src/FrontEnd/Web.Client` | WebAssembly 클라이언트 번들 | Auto Rendering 대상 컴포넌트, 클라이언트 전용 UI | 서버 전용 서비스, 비밀 정보 |
| `src/BackEnd/APIGateway` | 외부 진입점 및 라우팅 | YARP Reverse Proxy, 인증 위임, 라우트·클러스터 설정 | 개별 서비스의 도메인 처리 |
| `src/BackEnd/BuildingBlocks` | 최소 공통 기반 | 공통 계약 추상화, 메시징 추상화, 관측성 보조 코드 | 서비스별 Domain 모델, 유스케이스, DbContext |
| `src/BackEnd/Services/{ServiceName}` | 업무 서비스 경계 | Domain, Application, Infrastructure, Api, Contracts | 다른 서비스의 내부 구현 직접 참조 |
| `test` | 테스트 코드 | Unit, Integration, Contract, Functional, Architecture, E2E 테스트 | 운영 코드 |

## 2. FrontEnd 구조와 Blazor Auto Rendering 기준

프런트엔드는 `src/FrontEnd/Web`과 `src/FrontEnd/Web.Client`로 나눈다. `Web`은 Blazor Web App의 서버 호스트이며, `Web.Client`는 WebAssembly 기반 클라이언트 프로젝트다. Blazor의 Interactive Auto 렌더 모드는 최초에는 서버에서 Interactive SSR로 동작하고, 이후 WebAssembly 번들이 내려받아진 뒤에는 클라이언트 렌더링으로 전환되는 모델이다.[2]

Blazor Web App에서 Auto Rendering을 기본 전략으로 사용할 경우, 전역 상호작용 컴포넌트와 라우팅 컴포넌트의 위치가 중요하다. Microsoft 문서는 Interactive WebAssembly 또는 Auto 렌더링을 전역으로 적용하는 경우 레이아웃, 페이지, 라우트 컴포넌트가 클라이언트 프로젝트에 위치해야 하는 시나리오를 설명한다.[2] 따라서 이 프로젝트에서는 다음 규칙을 기본으로 둔다.

| 영역 | 기준 |
| --- | --- |
| 전역 렌더링 전략 | 기본은 `InteractiveAuto`를 우선 검토한다. 단, 인증·SEO·초기 로딩 요구사항에 따라 페이지별로 `Static SSR`, `InteractiveServer`, `InteractiveWebAssembly`를 분리할 수 있다. |
| 페이지 컴포넌트 | Auto 렌더링 대상 페이지는 가능하면 `Web.Client`에 둔다. 서버 전용 기능이 필요한 페이지는 `Web`에 둔다. |
| API 호출 | 클라이언트는 원칙적으로 `APIGateway`를 통해 백엔드 서비스 API에 접근한다. |
| 비밀 정보 | `Web.Client`에는 연결 문자열, API Key, 서버 비밀값을 두지 않는다. |
| 상태 관리 | UI 상태는 컴포넌트 또는 클라이언트 상태 서비스에 두고, 도메인 판단은 백엔드 Application 계층에서 처리한다. |
| 기본 UI 컴포넌트 | 일반 업무 화면, 레이아웃, 내비게이션, 폼, 다이얼로그, 테이블, 검증 UI는 **MudBlazor**를 우선 사용한다. |
| BI 관련 UI·기능 | 대시보드, 피벗·그리드 중심 분석 화면, 리포팅, 차트 중심 분석 페이지, 내보내기 중심 데이터 뷰는 **DevExpress Blazor 23.2.x** 기준으로 설계 가능성을 검토한다. |

MudBlazor는 Rev04의 기본 UI 컴포넌트 기준이다. 따라서 FrontEnd Agent는 단순 CRUD, 일반 업무 입력 화면, 공통 레이아웃, 탐색 메뉴, 다이얼로그, 폼 검증, 기본 데이터 표시에 대해 우선 MudBlazor 컴포넌트로 설계해야 한다. BI 성격이 없는 화면에 DevExpress를 기본 도입하지 않으며, 추가 패키지가 필요한 경우 목적, 대안, 라이선스 영향, 버전 고정 전략을 먼저 설명한다.

DevExpress Blazor는 **BI 관련 UI 또는 기능을 대비하기 위한 선택지**로 둔다. BI 관련 작업에는 대시보드, 고급 그리드, 피벗 성격의 분석 화면, 리포팅, 차트 중심 분석 페이지, 내보내기 중심 데이터 탐색 기능이 포함된다. DevExpress 계열 패키지는 사용자가 별도 승인하지 않는 한 23.2.x 버전 라인을 기준으로 검토하며, 라이선스 키, NuGet feed 인증 정보, 계정 정보는 소스 코드와 `Web.Client`, `appsettings`, 문서 예시에 직접 기록하지 않는다.

## 3. APIGateway 구조

`src/BackEnd/APIGateway`는 YARP 기반 Reverse Proxy 프로젝트로 둔다. YARP는 .NET 라이브러리로 제공되는 Reverse Proxy 기능이며, `Yarp.ReverseProxy` 패키지와 `AddReverseProxy().LoadFromConfig(...)`, `MapReverseProxy()` 구성을 통해 ASP.NET Core 앱에 프록시를 추가할 수 있다.[3]

이 프로젝트에서 Gateway는 외부 클라이언트와 내부 서비스 API 사이의 **경계면**이다. Gateway는 라우팅, 인증 위임, CORS, 공통 헤더, rate limiting, health check, correlation id 전달, observability를 담당하지만, 주문 생성, 회원 가입, 결제 승인 같은 비즈니스 유스케이스를 직접 처리하지 않는다.

| Gateway 관심사 | 처리 위치 | 원칙 |
| --- | --- | --- |
| 외부 URL 라우팅 | `APIGateway/appsettings*.json` 또는 코드 기반 설정 | 외부 경로와 내부 서비스 경로를 명확히 분리한다. |
| 인증·인가 | Gateway와 서비스 API 양쪽 | Gateway에서 1차 검증하되, 서비스 API도 최종 권한 검증을 수행한다. |
| Transform | Gateway | 사용자 식별자, correlation id, forwarded headers만 제한적으로 전달한다. |
| 도메인 판단 | 각 `{ServiceName}.Application` | Gateway에는 도메인 규칙을 두지 않는다. |
| 장애 격리 | Gateway + Aspire | 서비스별 timeout, retry, health 상태를 분리한다. |

## 4. BackEnd Services 구조

백엔드는 `src/BackEnd/Services/{ServiceName}` 단위로 확장한다. 각 서비스는 하나의 bounded context 후보이자 장래 독립 배포 후보로 간주한다. 처음에는 하나의 솔루션 안에서 함께 빌드하고 테스트할 수 있지만, 서비스 경계가 안정화되면 Aspire AppHost와 YARP를 통해 독립 실행 서비스로 분리할 수 있도록 설계한다.

권장 서비스 내부 구조는 다음과 같다.

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

Clean Architecture의 핵심은 도메인과 애플리케이션 정책이 프레임워크와 인프라 구현에 종속되지 않도록 의존성 방향을 통제하는 것이다. Microsoft의 ASP.NET Core 아키텍처 가이드는 애플리케이션이 커질수록 관심사 분리와 계층 간 의존성 제한이 유지보수성과 테스트 용이성을 높인다고 설명한다.[4]

| 계층 | 의존 가능 | 의존 금지 | 설명 |
| --- | --- | --- | --- |
| `{ServiceName}.Domain` | 없음 또는 순수 공통 추상화 | EF Core, ASP.NET Core, HTTP, DB, 외부 SDK, 다른 서비스 내부 구현 | 엔티티, 값 객체, 도메인 이벤트, 도메인 서비스가 위치한다. |
| `{ServiceName}.Application` | Domain | EF Core 구체 타입, ASP.NET Core 엔드포인트, 외부 SDK 직접 호출 | 유스케이스, command/query handler, port 인터페이스, DTO, 검증 규칙이 위치한다. |
| `{ServiceName}.Infrastructure` | Application, Domain, 필요한 Contracts | 다른 서비스 DB 직접 접근, 다른 서비스 내부 구현 | EF Core, Repository 구현, 외부 시스템 adapter, 파일·메일·메시징 구현이 위치한다. |
| `{ServiceName}.Api` | Application, Contracts | Infrastructure 구체 구현 직접 사용, 도메인 규칙 직접 구현 | Minimal API 엔드포인트, 요청·응답 계약, 인증 정책 연결이 위치한다. |
| `{ServiceName}.Contracts` | 없음 또는 BuildingBlocks.Contracts | Domain 내부 모델, Infrastructure 구현 | 공개 request/response, integration event, Gateway/FrontEnd 계약이 위치한다. |

## 5. TDD 기준 테스트 구조

테스트는 `test` 아래에 목적별로 분리한다. 핵심 원칙은 **도메인과 애플리케이션 유스케이스를 먼저 빠른 단위 테스트로 보호하고, 인프라와 API는 통합·기능·계약 테스트로 검증하는 것**이다.

| 테스트 경로 | 대상 | 실행 빈도 | 예시 |
| --- | --- | --- | --- |
| `test/Unit/Services/{ServiceName}` | Domain, Application | 매우 자주 | Aggregate 규칙, ValueObject 생성, UseCase 분기 |
| `test/Integration/Services/{ServiceName}` | Infrastructure, EF Core, 외부 adapter | PR 전 또는 기능 완성 시 | DbContext 매핑, Repository 구현, SQL Server 호환성 |
| `test/Contract/Services/{ServiceName}` | 서비스 공개 계약 | API 계약 변경 시 | request/response schema, integration event 호환성 |
| `test/Functional/APIGateway` | Gateway 라우팅과 보안 | Gateway 변경 시 | YARP route, auth forwarding, header transform |
| `test/Functional/FrontEnd` | Blazor 컴포넌트와 페이지 흐름 | UI 변경 시 | 렌더링, validation, API client interaction |
| `test/Architecture` | 의존성 규칙 | CI 및 PR | Domain이 Infrastructure를 참조하지 않는지 검증 |
| `test/EndToEnd` | 사용자 시나리오 | 릴리스 전 | 로그인부터 주요 업무 완료까지 |

TDD 흐름은 `Red → Green → Refactor`를 기본으로 한다. 새 유스케이스를 추가할 때 Codex에는 먼저 테스트 의도를 설명하게 하고, 실패 테스트를 작성한 뒤 최소 구현을 만들며, 마지막에 리팩터링과 아키텍처 규칙 검증을 수행하도록 요청한다.

## 6. 서비스 추가 규칙

새 업무 기능을 추가할 때는 `{ServiceName}`을 먼저 정한다. 이름은 도메인 언어를 사용하며, 기술 이름보다 업무 서비스 이름을 우선한다. 예를 들어 `Identity`, `Orders`, `Payments`, `Inventory`처럼 명확한 경계를 가진 이름을 사용한다.

| 단계 | 작업 | Codex 요청 예시 |
| --- | --- | --- |
| 1 | `{ServiceName}` 경계 정의 | `Orders 서비스를 추가하려고 해. 책임과 외부 계약 후보를 먼저 정리해줘.` |
| 2 | 서비스 폴더 생성 | `Services/_template 구조를 기준으로 Orders 서비스 폴더를 생성해줘.` |
| 3 | 도메인 모델 테스트 작성 | `Orders 도메인의 주문 생성 규칙을 테스트 먼저 작성해줘.` |
| 4 | Domain 구현 | `테스트를 만족하는 Aggregate와 ValueObject를 최소 구현해줘.` |
| 5 | Application 유스케이스 작성 | `CreateOrder command/usecase를 Clean Architecture 의존성 규칙에 맞게 작성해줘.` |
| 6 | Infrastructure 구현 | `EF Core 매핑과 Repository 구현을 작성하되 마이그레이션은 생성만 하고 적용하지 마.` |
| 7 | Api Endpoint 연결 | `Minimal API endpoint를 Api 계층에 추가하고 요청/응답 계약을 Contracts와 분리해줘.` |
| 8 | Gateway와 Aspire 연결 | `APIGateway와 AppHost에서 Orders API 연결 계획을 제시한 뒤 적용해줘.` |

## 7. 하이브리드 전략과 MSA 전환 기준

하이브리드 전략은 서비스 경계를 코드와 테스트에서 먼저 고정하고, 독립 배포·독립 DB·비동기 메시징은 필요가 확인될 때 도입하는 방식이다. 이 접근은 경계가 불안정한 초기 단계에서 분산 시스템 복잡도를 과도하게 떠안지 않으면서도, 장래 MSA 전환 비용을 낮추는 것을 목표로 한다.

| 판단 질문 | 예라면 MSA 분리 검토 | 아니오라면 단일 솔루션 유지 |
| --- | --- | --- |
| 서비스별 독립 배포가 필요한가? | 독립 Api 실행 프로젝트와 배포 파이프라인을 분리한다. | 같은 솔루션에서 함께 빌드·배포한다. |
| 서비스별 데이터 소유권이 명확한가? | DB/schema 분리와 migration 소유권을 분리한다. | 같은 DB를 쓰더라도 schema와 DbContext 경계를 먼저 분리한다. |
| 서비스 간 호출 계약이 안정적인가? | Contracts와 integration event versioning을 도입한다. | 내부 Application 경계를 먼저 안정화한다. |
| 장애 격리 요구가 높은가? | Gateway timeout, retry, circuit breaker, health policy를 서비스별로 분리한다. | 단순 라우팅과 공통 관측성부터 적용한다. |

## 8. Codex 작업 원칙

Codex가 이 구조를 다룰 때는 먼저 현재 변경 대상이 어느 계층인지 식별해야 한다. 이후 해당 계층의 의존성 규칙을 확인하고, 테스트를 먼저 제안한 뒤 코드를 작성해야 한다. 특히 EF Core 마이그레이션, Gateway 라우팅, 인증·인가, Blazor Auto Rendering 위치 변경, 서비스 간 계약 변경은 영향 범위가 크므로 변경 전 계획과 변경 후 검증 결과를 반드시 남긴다.

> Codex는 `Domain → Application → Infrastructure → Api → Gateway → FrontEnd → Aspire` 순서로 영향 범위를 추적한다. 의존성 방향은 반대로 흐르지 않도록 관리한다.

## References

[1]: https://learn.microsoft.com/en-us/dotnet/aspire/fundamentals/app-host-overview "Aspire AppHost overview"
[2]: https://learn.microsoft.com/en-us/aspnet/core/blazor/components/render-modes "ASP.NET Core Blazor render modes"
[3]: https://learn.microsoft.com/en-us/aspnet/core/fundamentals/servers/yarp/getting-started "Get started with YARP"
[4]: https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures "Common web application architectures"
