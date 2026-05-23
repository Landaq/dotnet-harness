# 백엔드 서비스 템플릿

이 문서는 `src/BackEnd/Services/{ServiceName}` 아래에 새 업무 서비스를 추가할 때 사용하는 표준 구조를 정의한다. 각 서비스는 **DDD의 bounded context 후보**이자 장래 **독립 배포 가능한 MSA 서비스 후보**이며, 초기에는 단일 솔루션 안에서 함께 개발될 수 있다.

## 1. 기본 구조

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

## 2. 계층별 책임

| 계층 | 핵심 책임 | 허용되는 코드 | 금지되는 코드 |
| --- | --- | --- | --- |
| `{ServiceName}.Domain` | 업무 규칙과 상태 전이 보호 | Aggregate, Entity, ValueObject, Domain Event, Repository 인터페이스 | EF Core, ASP.NET Core, HTTP, JSON serialization, 외부 API SDK, 다른 서비스 내부 구현 |
| `{ServiceName}.Application` | 유스케이스 흐름 조정 | Command, Query, Handler, DTO, Validator, Port 인터페이스 | DbContext 직접 사용, Controller/Endpoint, 외부 SDK 직접 호출, 다른 서비스 Infrastructure 참조 |
| `{ServiceName}.Infrastructure` | 외부 기술 구현 | EF Core DbContext, Repository 구현, 외부 API Adapter, 파일·메일·메시징 구현 | 비즈니스 정책 결정, HTTP Endpoint, 다른 서비스 DB 직접 접근 |
| `{ServiceName}.Api` | HTTP 경계 | Minimal API endpoint, endpoint mapping, auth policy 연결 | EF Core 직접 사용, 도메인 규칙 직접 구현 |
| `{ServiceName}.Contracts` | 외부 공개 계약 | Request, Response, integration event, API client 계약 타입 | Domain 모델 직접 노출, Infrastructure 구현 타입 |

## 3. 의존성 규칙

서비스 내부의 의존성 방향은 항상 안쪽으로 향한다. `Api`와 `Infrastructure`는 `Application`과 `Domain`에 의존할 수 있지만, `Domain`과 `Application`은 바깥 계층의 구현에 의존하지 않는다. `Contracts`는 외부 공개 계약이므로 Domain 내부 모델에 의존하지 않아야 한다.

| From | To | 허용 여부 |
| --- | --- | --- |
| `Domain` | `Application`, `Infrastructure`, `Api`, 다른 서비스 내부 구현 | 금지 |
| `Application` | `Domain` | 허용 |
| `Application` | `Infrastructure`, `Api`, 다른 서비스 내부 구현 | 금지 |
| `Infrastructure` | `Application`, `Domain`, 필요한 `Contracts` | 허용 |
| `Api` | `Application`, `Contracts` | 허용 |
| `Api` | `Infrastructure` 구체 구현 | 기본 금지. DI 등록 경계에서만 제한적으로 허용 |
| `Contracts` | `Domain`, `Infrastructure`, `Api` | 금지 |

## 4. 새 서비스 생성 절차

새 서비스를 만들 때는 `Services/_template` 폴더를 복사한 뒤 `{ServiceName}` 이름으로 변경한다. 서비스 이름은 기술 이름이 아니라 도메인 언어를 사용한다. 예를 들어 `AccountService`보다 `Identity`, `OrderApi`보다 `Orders`가 적합하다.

| 순서 | 작업 | 산출물 |
| --- | --- | --- |
| 1 | 서비스 경계 정의 | `{ServiceName}` 이름, 책임 문장, 외부 계약 후보 |
| 2 | 도메인 규칙 테스트 작성 | `test/Unit/Services/{ServiceName}` |
| 3 | Domain 모델 작성 | Aggregate, ValueObject, Domain Event |
| 4 | Application 유스케이스 작성 | Command/Query Handler, Port 인터페이스 |
| 5 | Infrastructure 구현 | DbContext, Repository, Adapter |
| 6 | Api 엔드포인트 연결 | Minimal API endpoint, request/response mapping |
| 7 | Contract 테스트 작성 | `test/Contract/Services/{ServiceName}` |
| 8 | Gateway 라우팅 추가 | `APIGateway`의 YARP route/cluster |
| 9 | Aspire 등록 | `AppHost`의 프로젝트 및 리소스 연결 |

## 5. MSA 전환 준비 기준

서비스를 처음부터 독립 배포하지 않더라도, 다음 기준을 만족하면 나중에 MSA로 분리하기 쉬워진다.

| 기준 | 설명 |
| --- | --- |
| 공개 계약 분리 | 외부 호출 타입은 `{ServiceName}.Contracts`에 둔다. |
| 데이터 소유권 | 서비스별 DbContext와 migration 소유권을 분리한다. |
| 내부 구현 은닉 | 다른 서비스가 Domain/Application/Infrastructure 내부 타입을 직접 참조하지 않는다. |
| Gateway 경유 | 외부 클라이언트는 APIGateway를 통해 서비스 API를 호출한다. |
| Aspire 연결 | 실행 프로젝트와 리소스 의존성을 AppHost에서 명시한다. |

## 6. Codex에게 요청할 때의 기준 문장

Codex에게 서비스 작업을 요청할 때는 다음 기준 문장을 함께 제공한다.

> `{ServiceName}` 서비스를 `src/BackEnd/Services/{ServiceName}` 아래에 Clean Architecture와 DDD 구조로 작성해줘. 먼저 실패하는 단위 테스트를 만들고, Domain과 Application 계층을 구현한 뒤, Infrastructure와 Api는 의존성 규칙을 지키며 분리해줘. 외부 공개 타입은 `{ServiceName}.Contracts`에 두고, Gateway와 Aspire 연결은 별도 단계로 계획을 제시한 후 적용해줘.

## 7. 완료 기준

서비스 작업은 단순히 코드가 생성되었다고 완료되지 않는다. 다음 기준이 충족되어야 한다.

| 기준 | 설명 |
| --- | --- |
| 테스트 | Domain과 Application 핵심 규칙에 대한 단위 테스트가 존재한다. |
| 의존성 | Domain과 Application이 Infrastructure 또는 Api를 참조하지 않는다. |
| 계약 분리 | HTTP 요청·응답 계약과 integration event가 Domain 모델과 직접 결합되지 않는다. |
| Gateway | 외부 노출 경로가 APIGateway에서 명확히 정의된다. |
| Observability | 로그, trace, health check 기준을 ServiceDefaults 또는 서비스 설정에서 따른다. |
| 문서 | 서비스 경계와 주요 유스케이스가 서비스 README 또는 ADR에 남아 있다. |
