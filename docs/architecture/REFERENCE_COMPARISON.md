# Rev04 프로젝트 구조 외부 레퍼런스 비교 분석

작성자: **Manus AI**

## 1. 결론 요약

현재 Rev04 구상은 큰 방향에서 최신 .NET 풀스택 아키텍처 흐름과 잘 맞는다. `src/Aspire/AppHost`, `src/Aspire/ServiceDefaults`, `src/FrontEnd/Web`, `src/FrontEnd/Web.Client`, `src/BackEnd/APIGateway`, `src/BackEnd/BuildingBlocks`, `src/BackEnd/Services/{ServiceName}`, `test`로 나누는 구조는 Aspire, Blazor Auto Rendering, YARP, 서비스 경계 기반 DDD, TDD를 함께 운영하기에 적절하다.[1] [2] [3]

다만 외부 레퍼런스와 비교하면 네 가지 보강점이 분명하다. 첫째, 솔루션 파일은 사용자의 기준대로 `Rev04.slnx`를 1차 표준으로 고정해야 한다. 둘째, `src/BackEnd/Services/{ServiceName}` 아래의 `Domain`, `Application`, `Infrastructure`, `Api`, `Contracts`를 서비스 경계로 유지하되, 장기적으로 별도 프로젝트 분리가 가능하게 해야 한다. 셋째, 루트에 `global.json`, `Directory.Build.props`, `Directory.Packages.props`를 두어 SDK, 빌드 정책, 패키지 버전을 중앙 관리해야 한다. 넷째, 테스트 구조는 `test/Unit/Services/{ServiceName}`처럼 서비스 경계와 실제 `.csproj` 단위가 드러나는 구조가 Codex와 CI 관점에서 더 명확하다.

> Rev04의 현재 구상은 **방향은 올바르지만, `.slnx` 중심의 솔루션 구성, 중앙 빌드 정책, 서비스 단위 프로젝트 경계, 아키텍처 테스트**를 추가해야 장기적으로 안정적인 코딩 보조 환경이 된다.

## 2. 레퍼런스별 비교

| 레퍼런스 | 핵심 구조 | Rev04와 일치하는 부분 | Rev04에 보강할 부분 |
| --- | --- | --- | --- |
| Microsoft Aspire 문서 | AppHost가 서비스와 리소스 의존관계를 선언하고, ServiceDefaults가 관측성·상태점검·서비스 디스커버리 기본값을 제공한다.[1] | `src/Aspire/AppHost`, `src/Aspire/ServiceDefaults` 분리는 적절하다. | ServiceDefaults에 공통 DTO, 도메인 모델, 유틸리티를 넣지 못하게 규칙을 강화해야 한다. |
| Blazor render modes 문서 | Interactive Auto는 서버 기반 상호작용 후 WebAssembly 번들이 준비되면 클라이언트 실행을 활용한다.[2] | `src/FrontEnd/Web`과 `src/FrontEnd/Web.Client` 분리는 적절하다. | Auto Rendering 컴포넌트의 위치, 서버 전용 의존성, 브라우저 전용 API 접근 규칙을 더 명확히 해야 한다. |
| YARP 공식 문서 | ASP.NET Core에서 Reverse Proxy를 구성하고 라우트와 클러스터를 정의한다.[3] | `src/BackEnd/APIGateway` 독립은 적절하다. | Gateway가 도메인 유스케이스를 직접 처리하지 않도록 Codex rules에 강하게 반영해야 한다. |
| Jason Taylor CleanArchitecture | 최신 템플릿은 Aspire와 `.slnx`, `src`, `tests`, 중앙 빌드·패키지 파일을 함께 사용한다.[4] | `.slnx` 기준과 Aspire 도입 방향이 잘 맞는다. | `Rev04.slnx`, `global.json`, `Directory.Build.props`, `Directory.Packages.props`를 루트 표준으로 추가해야 한다. |
| kgrzybek modular-monolith-with-ddd | 모듈형 모놀리스, DDD 전술 패턴, CQRS, 도메인 이벤트, 통합 테스트, 아키텍처 테스트를 포함한다.[5] | `Services/{ServiceName}`을 독립 bounded context 후보로 다루는 방향과 잘 맞는다. | 각 서비스를 장래 독립 배포 가능한 경계로 보고 public contracts와 internal 구현을 분리해야 한다. |
| eShopOnWeb | `src`와 `tests` 분리, Core/Infrastructure/Web 계층, EF Core, 단일 배포 아키텍처를 보여준다.[6] | 테스트 분리와 인프라 격리 원칙은 참고할 수 있다. | 최신 `.slnx`/Aspire 기준은 아니므로 직접 복제보다 원칙만 참고하는 것이 적절하다. |
| Milan Jovanović 모듈형 모놀리스 정리 | 모듈은 특정 business capability를 캡슐화하고 자체 데이터·로직·API surface를 가진다.[7] | 기능 단위 모듈화 방향과 일치한다. | 모듈 간 내부 구현 참조 금지, internal/public API 구분, 아키텍처 테스트를 도입해야 한다. |

## 3. 현재 Rev04 구조의 강점

Rev04의 가장 큰 강점은 처음부터 프런트엔드, 게이트웨이, 백엔드 서비스 경계, Aspire 오케스트레이션을 분리한 점이다. 이는 나중에 단일 모놀리스에서 분산 서비스로 일부 기능을 분리할 가능성을 열어 둔다. 특히 `src/BackEnd/APIGateway`를 별도 프로젝트 영역으로 둔 점은 YARP 기반 gateway, BFF, 인증·인가 경계, 관측성 정책을 한 곳에 모으기 좋다.[3]

또한 `src/FrontEnd/Web`과 `src/FrontEnd/Web.Client`를 분리한 것은 Blazor Web App의 Interactive Auto Rendering 흐름과 맞는다. Interactive WebAssembly 또는 Auto 렌더링을 사용할 때 클라이언트 프로젝트가 필요한 구조이므로, 서버 호스트와 클라이언트 번들을 처음부터 나누는 현재 구상은 합리적이다.[2]

백엔드를 `src/BackEnd/Services/{ServiceName}`로 확장하려는 방향은 MSA-ready 하이브리드 구조와 DDD에 적합하다. 초기에는 단일 솔루션의 단순성을 유지하면서 서비스 경계를 명시하고, 각 서비스가 business capability를 캡슐화하도록 설계하는 것이 핵심이다.[7]

## 4. 현재 Rev04 구조의 위험 요소

현재 문서의 서비스 내부 구조는 `Domain`, `Application`, `Infrastructure`, `Api`, `Contracts`를 경계로 표현하고 있다. 초기에는 간단하지만, Codex CLI와 CI가 의존성 규칙을 자동 검증하기에는 별도 `.csproj` 경계가 더 유리하다. 예를 들어 `Orders.Domain.csproj`가 `Orders.Infrastructure.csproj`를 참조하지 못하게 하는 것은 프로젝트 참조와 아키텍처 테스트로 명확히 검증할 수 있다.

또 다른 위험은 `ServiceDefaults`가 시간이 지나면서 공통 유틸리티 프로젝트처럼 오염될 가능성이다. Aspire의 ServiceDefaults는 관측성, health check, service discovery, resilience 같은 실행 기본값을 공유하는 목적이므로, 도메인 모델이나 공통 DTO를 넣으면 계층 경계가 흐려진다.[1]

Gateway 역시 주의가 필요하다. YARP Gateway는 routing, transform, authentication, observability 같은 cross-cutting 기능에는 적합하지만, 도메인 유스케이스를 직접 처리하면 모든 기능이 Gateway에 결합된다.[3] 따라서 Gateway는 외부 API 경계와 라우팅 정책만 담당하고, 실제 업무 처리는 각 서비스의 Api/Application 계층에 남겨야 한다.

## 5. 권장 목표 구조

아래 구조는 사용자가 제시한 큰 틀을 유지하면서, `.slnx`, Clean Architecture, DDD, TDD, Codex 자동 작업에 더 적합하도록 세분화한 구조다.

```text
Rev04/
  Rev04.slnx
  global.json
  Directory.Build.props
  Directory.Packages.props
  src/
    Aspire/
      AppHost/
        Rev04.Aspire.AppHost.csproj
      ServiceDefaults/
        Rev04.Aspire.ServiceDefaults.csproj
    FrontEnd/
      Web/
        Rev04.FrontEnd.Web.csproj
      Web.Client/
        Rev04.FrontEnd.Web.Client.csproj
    BackEnd/
      APIGateway/
        Rev04.BackEnd.APIGateway.csproj
      BuildingBlocks/
        Contracts/
        Messaging/
        Observability/
      Services/
        {ServiceName}/
          {ServiceName}.Domain/
            Rev04.BackEnd.Services.{ServiceName}.Domain.csproj
          {ServiceName}.Application/
            Rev04.BackEnd.Services.{ServiceName}.Application.csproj
          {ServiceName}.Infrastructure/
            Rev04.BackEnd.Services.{ServiceName}.Infrastructure.csproj
          {ServiceName}.Api/
            Rev04.BackEnd.Services.{ServiceName}.Api.csproj
          {ServiceName}.Contracts/
            Rev04.BackEnd.Services.{ServiceName}.Contracts.csproj
  test/
    Unit/
      Services/
        {ServiceName}/
          Rev04.BackEnd.Services.{ServiceName}.Domain.Tests.csproj
          Rev04.BackEnd.Services.{ServiceName}.Application.Tests.csproj
    Integration/
      Services/
        {ServiceName}/
          Rev04.BackEnd.Services.{ServiceName}.Integration.Tests.csproj
    Functional/
      APIGateway/
        Rev04.BackEnd.APIGateway.FunctionalTests.csproj
      FrontEnd/
        Rev04.FrontEnd.FunctionalTests.csproj
    Architecture/
      Rev04.Architecture.Tests.csproj
    EndToEnd/
      Rev04.EndToEnd.Tests.csproj
```

## 6. 구조 결정 매트릭스

| 결정 항목 | 현재 구상 | 레퍼런스 기반 개선안 | 우선순위 |
| --- | --- | --- | --- |
| 솔루션 파일 | 아직 `.slnx` 기준 반영 필요 | `Rev04.slnx`를 표준으로 하고 모든 문서·Codex 지침에서 `.slnx`만 언급 | 높음 |
| 서비스 내부 단위 | 폴더 또는 프로젝트 중심 | 장기적으로 `Domain/Application/Infrastructure/Api/Contracts`를 각각 `.csproj`로 분리 | 높음 |
| 공통 설정 | 명시 약함 | `global.json`, `Directory.Build.props`, `Directory.Packages.props` 추가 | 높음 |
| ServiceDefaults | 역할은 정의됨 | 도메인·DTO·유틸리티 금지 규칙 추가 | 높음 |
| Gateway | 역할은 정의됨 | 도메인 로직 금지, 라우팅·보안·관측성 한정 규칙 추가 | 높음 |
| 테스트 | `test` 아래 목적별 분리 | 실제 테스트 `.csproj` 기준까지 문서화 | 중간 |
| 아키텍처 테스트 | 언급 있음 | NetArchTest 또는 ArchUnitNET 계열 도입 후보 문서화 | 중간 |
| 서비스 간 통신 | 아직 개략적 | Public Contracts, domain events, integration events, direct DB 접근 금지 규칙 추가 | 중간 |

## 7. Codex 지침에 반영할 핵심 규칙

Codex가 프로젝트를 수정할 때는 먼저 `Rev04.slnx`를 기준으로 프로젝트 목록을 확인해야 한다. 새 프로젝트를 만들면 반드시 `.slnx`에 추가하고, 문서와 테스트 프로젝트도 함께 갱신해야 한다. `.sln` 파일을 임의로 생성하거나 기존 기준 파일처럼 사용해서는 안 된다.

업무 서비스를 추가할 때는 최소한 `Domain`, `Application`, `Infrastructure`, `Api`, `Contracts`의 책임을 구분해야 한다. 프로젝트 분리를 아직 하지 않는 경우에도 폴더 책임은 동일하게 유지해야 하며, 프로젝트 분리를 할 경우 의존성 방향은 `Api → Application → Domain`, `Infrastructure → Application/Domain` 흐름으로 제한해야 한다.

TDD 작업에서는 Domain 테스트와 Application 테스트를 먼저 작성하고, Infrastructure와 API는 통합 테스트 또는 기능 테스트로 보강한다. 아키텍처 테스트는 단순 선택 사항이 아니라, Codex가 대규모 변경을 수행할 때 의존성 회귀를 막는 안전장치로 간주해야 한다.

## References

[1]: https://learn.microsoft.com/en-us/dotnet/aspire/fundamentals/app-host-overview "Aspire AppHost overview"
[2]: https://learn.microsoft.com/en-us/aspnet/core/blazor/components/render-modes "ASP.NET Core Blazor render modes"
[3]: https://learn.microsoft.com/en-us/aspnet/core/fundamentals/servers/yarp/getting-started "Get started with YARP"
[4]: https://github.com/jasontaylordev/CleanArchitecture "Jason Taylor CleanArchitecture"
[5]: https://github.com/kgrzybek/modular-monolith-with-ddd "kgrzybek modular-monolith-with-ddd"
[6]: https://github.com/dotnet-architecture/eShopOnWeb "Microsoft eShopOnWeb"
[7]: https://www.milanjovanovic.tech/blog/modular-monolith-architecture-dotnet "Modular Monolith Architecture in .NET"
