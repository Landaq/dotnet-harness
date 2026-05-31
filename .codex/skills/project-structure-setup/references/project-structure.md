# PROJECT_STRUCTURE.md 기반 폴더 규칙 정리

이 스킬은 프로젝트명을 변수로 받는다.

## 기본 구조

- `src/Aspire/{AppHost,ServiceDefaults}`
- `src/FrontEnd/{Web,Web.Client}`
- `src/BackEnd/APIGateway`
- `src/BackEnd/BuildingBlocks/{Contracts,Messaging,Observability}`
- `test/{Architecture,Unit,Integration,Contract,Functional/{APIGateway,FrontEnd},EndToEnd}`

## 서비스 추가 시

- `src/BackEnd/Services/{ServiceName}/{ServiceName}.Domain`
- `src/BackEnd/Services/{ServiceName}/{ServiceName}.Application`
- `src/BackEnd/Services/{ServiceName}/{ServiceName}.Infrastructure`
- `src/BackEnd/Services/{ServiceName}/{ServiceName}.Api`
- `src/BackEnd/Services/{ServiceName}/{ServiceName}.Contracts`
- `test/{Unit,Integration,Contract}/Services/{ServiceName}`

기능/코드는 생성하지 않고, 폴더 뼈대만 만든다.
