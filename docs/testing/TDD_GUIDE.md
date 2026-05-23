# TDD 및 테스트 전략

이 프로젝트는 **TDD를 기본 개발 흐름**으로 삼는다. 모든 기능은 가능한 한 테스트로 의도를 먼저 고정하고, 최소 구현을 작성한 뒤, 구조와 이름을 리팩터링하는 방식으로 진행한다. Rev04의 현재 백엔드 기준은 기존 모듈 방식이 아니라 **`Services/{ServiceName}` 기반의 MSA-ready 하이브리드 서비스 구조**다.

## 1. 기본 개발 흐름

TDD 흐름은 `Red → Green → Refactor`를 따른다. `Red` 단계에서는 실패하는 테스트를 작성해 요구사항을 명확히 한다. `Green` 단계에서는 테스트를 통과하는 최소 구현만 작성한다. `Refactor` 단계에서는 중복 제거, 이름 개선, 계층 분리, 서비스 경계, 의존성 규칙 검증을 수행한다.

| 단계 | 목적 | Codex 요청 방식 |
| --- | --- | --- |
| Red | 요구사항을 테스트로 고정 | `이 유스케이스에 대해 실패하는 테스트를 먼저 작성해줘.` |
| Green | 최소 구현 | `테스트를 통과하는 최소 구현만 작성해줘.` |
| Refactor | 구조 개선 | `Clean Architecture, DDD, 서비스 경계 규칙에 맞게 리팩터링하되 테스트는 유지해줘.` |

## 2. 테스트 폴더 구조

```text
test/
  Architecture/
  Unit/
    Services/
      {ServiceName}/
  Integration/
    Services/
      {ServiceName}/
  Contract/
    Services/
      {ServiceName}/
  Functional/
    APIGateway/
    FrontEnd/
  EndToEnd/
```

| 테스트 유형 | 대상 | 원칙 |
| --- | --- | --- |
| Unit | Domain, Application | 가장 빠르고 자주 실행한다. 외부 인프라를 사용하지 않는다. |
| Integration | Infrastructure, EF Core, SQL Server | 실제 기술 통합을 검증한다. Testcontainer 또는 로컬 개발 DB 사용을 검토한다. |
| Contract | 서비스 공개 계약, integration event | 서비스 간 계약 변경을 보호한다. Domain 내부 모델과 공개 계약이 결합되지 않았는지 확인한다. |
| Functional | API Gateway, Minimal API, Blazor UI 단위 흐름 | HTTP 경계와 사용자 관점 동작을 검증한다. |
| Architecture | 계층 의존성, 네이밍, 참조 규칙 | CI에서 반드시 실행한다. |
| EndToEnd | 주요 사용자 시나리오 | 릴리스 또는 주요 병합 전에 실행한다. |

## 3. 백엔드 서비스 개발 순서

백엔드 서비스는 항상 도메인 규칙에서 시작한다. 예를 들어 주문 서비스를 추가한다면 `Order` Aggregate의 생성 규칙, 상태 전이, 취소 가능 조건을 먼저 테스트로 표현한다. 이후 Application 계층에서 `CreateOrder`, `CancelOrder`, `GetOrderDetail` 같은 유스케이스를 구현하고, 마지막에 Infrastructure와 Api를 연결한다.

| 순서 | 테스트 대상 | 구현 대상 |
| --- | --- | --- |
| 1 | Domain 규칙 | Aggregate, ValueObject, Domain Event |
| 2 | Application 유스케이스 | Command/Query Handler, Port 인터페이스 |
| 3 | Contract | Request/Response, integration event, API client 계약 |
| 4 | Infrastructure 통합 | EF Core mapping, Repository 구현 |
| 5 | Api 경계 | Minimal API endpoint, request/response mapping |
| 6 | Gateway | YARP route, auth forwarding, header transform |
| 7 | FrontEnd | Blazor page/component, API client |
| 8 | Aspire | AppHost project/resource wiring |

## 4. 프런트엔드 테스트 기준

Blazor Web App은 Auto Rendering을 기준으로 하므로 컴포넌트가 서버와 클라이언트 어디에서 실행될 수 있는지 확인해야 한다. 클라이언트에서 실행되는 컴포넌트는 서버 전용 서비스, 파일 시스템, 비밀 정보, 직접 DB 접근에 의존하지 않아야 한다.

| 대상 | 확인 사항 |
| --- | --- |
| `Web.Client` 컴포넌트 | 브라우저에서 동작 가능한 의존성만 사용한다. |
| `Web` 서버 호스트 | 인증, 라우팅, 서버 전용 서비스 연결을 담당한다. |
| API Client | Gateway 경유 URL을 사용한다. |
| 상태 | UI 상태와 도메인 판단을 분리한다. |

## 5. 서비스 계약 테스트 기준

하이브리드 전략에서는 초기부터 모든 서비스를 독립 배포하지 않더라도, 서비스 간 계약은 독립 배포를 가정하고 보호해야 한다. 공개 요청·응답 타입과 integration event는 `{ServiceName}.Contracts`에 두며, 테스트는 `test/Contract/Services/{ServiceName}` 아래에 둔다.

| 확인 항목 | 기준 |
| --- | --- |
| 요청·응답 계약 | Domain 모델을 그대로 노출하지 않는다. |
| 버전 호환성 | 기존 클라이언트를 깨뜨리는 변경은 명시적으로 표시한다. |
| Integration Event | 이벤트 이름, 필수 필드, idempotency key, timestamp 기준을 검증한다. |
| Gateway 경로 | 외부 URL과 내부 서비스 endpoint가 의도대로 매핑되는지 확인한다. |

## 6. Codex 사용 규칙

Codex에게 기능 구현을 맡길 때는 바로 구현을 지시하지 않는다. 먼저 테스트 계획과 변경 범위를 쓰게 한 다음, 테스트 작성과 구현을 분리한다.

> 좋은 요청 예시는 다음과 같다. `Orders 서비스에 주문 생성 기능을 추가하려고 해. 먼저 Domain/Application/Contract 테스트 케이스를 제안하고, 실패 테스트를 작성한 뒤 최소 구현을 진행해줘. Infrastructure, Api, Gateway, Aspire 변경은 별도 단계로 나눠줘.`

## 7. 완료 기준

| 항목 | 완료 조건 |
| --- | --- |
| 단위 테스트 | 핵심 도메인 규칙과 Application 유스케이스가 테스트된다. |
| 계약 테스트 | 공개 API 계약 또는 integration event 변경이 테스트된다. |
| 통합 테스트 | EF Core 매핑과 Repository 구현이 검증된다. |
| 기능 테스트 | API Gateway 또는 Minimal API 경계가 검증된다. |
| 아키텍처 테스트 | 계층 간 금지 참조와 서비스 간 내부 구현 참조가 발생하지 않는다. |
| 문서 | 서비스 경계와 주요 의사결정이 문서화된다. |
