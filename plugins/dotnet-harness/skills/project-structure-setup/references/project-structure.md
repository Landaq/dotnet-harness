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
- `test/{Unit,Integration,Contract}/Services/{ServiceName}`

비즈니스 기능 코드는 생성하지 않는다. 대신 빌드 가능한 baseline `.csproj`,
solution entry, smoke test project, AppHost/Gateway wiring, launch settings,
harness config를 생성한다.

## 설정 오버라이드

- 기본 scaffold profile은 .NET 10, Aspire, Clean Architecture, DDD, YARP, Scalar, SQL Server, Redis, Blazor Auto, MudBlazor이다.
- setup script는 `.codex/harness-config.json`이 없으면 기본 UI/library 정책 값을 생성한다.
- 이후 Task Agents는 `.codex/harness-config.json`을 해당 프로젝트의 UI/library 정책 override로 읽는다.
- 현재 setup script는 기본 profile을 생성하며, Vertical Slice Architecture, Simple API, 다른 UI library scaffold는 다음 release 범위다.
