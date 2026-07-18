# PROJECT_STRUCTURE.md 기반 폴더 규칙 정리

이 스킬은 프로젝트명을 변수로 받는다.

## 기본 구조

- `src/Aspire/{AppHost,ServiceDefaults}`
- `src/FrontEnd/{Web,Web.Client}`
- `src/BackEnd/APIGateway`
- `src/BackEnd/BuildingBlocks/{Contracts,Messaging,Observability}`
- `test/{Architecture,Unit,Integration,Contract,Functional/{APIGateway,FrontEnd},EndToEnd}`
- `docs/Project/README.md`: baseline structure summary created by `project-structure-setup`
- `.codex/harness-config.json`: project policy override defaults for later Task Agents routing

## 서비스 추가 시

- `src/BackEnd/Services/{ServiceName}/{ServiceName}.Domain`
- `src/BackEnd/Services/{ServiceName}/{ServiceName}.Application`
- `src/BackEnd/Services/{ServiceName}/{ServiceName}.Infrastructure`
- `src/BackEnd/Services/{ServiceName}/{ServiceName}.Api`
- `src/BackEnd/Services/{ServiceName}/{ServiceName}.Contracts`
- `test/{Unit,Integration,Contract}/Services/{ServiceName}`: production layer를
  참조하는 빌드 가능한 서비스별 test project

비즈니스 기능 코드는 생성하지 않는다. 대신 빌드 가능한 baseline `.csproj`,
solution entry, smoke test project, AppHost/Gateway wiring, launch settings,
harness config를 생성한다.

생성된 테스트 프로젝트는 실제 production 프로젝트를 `ProjectReference`로 참조하며,
mediator 계약, Application 의존 방향, API Gateway HTTP health endpoint를 검사한다.
Blazor baseline은 router와 head outlet을 `InteractiveAuto` 경계에서 실행하고 client
assembly를 명시적으로 검색한다. MudBlazor의 theme, popover, dialog, snackbar
provider와 로컬 CSS/JavaScript asset도 이 interactive 경계에 포함한다.

## 이름 및 재실행 안전성

- `ProjectName`과 `ServiceName`은 파일 생성 전에 검증한다. traversal, 경로 구분자,
  quote, control/formatting 문자를 허용하지 않는다.
- `ServiceName`은 공백 제거 후 ASCII C# identifier여야 한다.
- 생성 파일명의 이식성을 위해 `ProjectName`은 120자, `ServiceName`은 64자로 제한한다.
- Aspire resource name은 ASCII letter로 시작하고, 연속 hyphen을 제거하며, suffix를
  포함해 64자를 넘지 않도록 정규화한다.
- 기존 no-service scaffold에는 생성기를 재실행해 서비스를 추가하지 않는다.
  기존 AppHost, Gateway, solution을 덮어쓰지 않는 계약 때문에 불완전한 wiring이
  생길 수 있으므로 task workflow를 통해 함께 변경한다.

## 설정 오버라이드

- 기본 scaffold profile은 .NET 10, Aspire, Clean Architecture, DDD, YARP, Scalar, SQL Server, Redis, Blazor Auto, MudBlazor이다.
- setup script는 `.codex/harness-config.json`이 없으면 기본 UI/library 정책 값을 생성한다.
- 이후 Task Agents는 `.codex/harness-config.json`을 해당 프로젝트의 UI/library 정책 override로 읽는다.
- 현재 setup script는 기본 profile을 생성하며, Vertical Slice Architecture, Simple API, 다른 UI library scaffold는 다음 release 범위다.
