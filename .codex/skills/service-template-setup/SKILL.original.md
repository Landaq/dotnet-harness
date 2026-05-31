---
name: service-template-setup
description: Scaffold and enforce the ServiceName folder and layer structure for a new backend service using Domain, Application, Infrastructure, Api, and Contracts boundaries.
---

# Service Template Setup

Use this skill whenever a new backend service folder is being introduced under `src/BackEnd/Services/{ServiceName}`.

## Inputs

- Service name (`ServiceName`) from user request
- Optional: whether this is a new service or existing service expansion

## Mandatory structure

- `src/BackEnd/Services/{ServiceName}/{ServiceName}.Domain/`
  - `Aggregates`, `Entities`, `ValueObjects`, `Events`, `Repositories`
- `src/BackEnd/Services/{ServiceName}/{ServiceName}.Application/`
  - `Abstractions`, `UseCases/Commands`, `UseCases/Queries`, `DTOs`, `Validators`
- `src/BackEnd/Services/{ServiceName}/{ServiceName}.Infrastructure/`
  - `Persistence/Configurations`, `Persistence/Migrations`, `Repositories`, `Integrations`
- `src/BackEnd/Services/{ServiceName}/{ServiceName}.Api/`
  - `Endpoints`, `Mapping`
- `src/BackEnd/Services/{ServiceName}/{ServiceName}.Contracts/`
  - `Requests`, `Responses`, `IntegrationEvents`
- Test folders
  - `test/Unit/Services/{ServiceName}`
  - `test/Integration/Services/{ServiceName}`
  - `test/Contract/Services/{ServiceName}`

## Dependency rules

- `{ServiceName}.Domain` and `{ServiceName}.Application` must not reference outer implementation layers.
- `{ServiceName}.Api` and `{ServiceName}.Infrastructure` may depend on `Application`/`Domain` and only where allowed.
- `{ServiceName}.Contracts` must remain transport-oriented types and public models.

## Workflow

1. Confirm service boundary and owner terms first.
2. Define contract surface before endpoint implementation.
3. Create only structure and test folders needed for the requested scope.
4. Keep API and domain concerns separated; avoid placing business rules in Api layer.
5. Only route through gateway and AppHost after Domain and Application are stable.

## Completion checks

- Domain and Application have no accidental dependency on Infrastructure/Api concrete types.
- `Contracts` types are not direct domain models.
- API path and gateway route are added in separate steps.

## Helpful commands

- Review baseline service template in `[references/service-template.md](references/service-template.md)`.
- Ask in Korean for missing service names or boundary decisions, then continue in English for implementation instructions.
