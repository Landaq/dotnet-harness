---
name: service-template-setup
description: "Create or review a new backend service using dotnet-harness service-layer template rules, enforce Domain/Application/Infrastructure/Api/Contracts boundaries, and validate test placement."
---

# Service Template Setup

Use this skill when a user asks to add, review, or refactor a new service under `src/BackEnd/Services/{ServiceName}`.

## Scope

- Create folder layout and optional test folders for a new service.
- Enforce DDD layer responsibilities and dependency direction.
- Confirm public contracts stay in `Contracts` and infrastructure details stay in `Infrastructure`.
- Keep API/domain boundaries from being merged during scaffold planning.

## Canonical Service Layout

```text
src/BackEnd/Services/{ServiceName}/
  {ServiceName}.Domain/
  {ServiceName}.Application/
  {ServiceName}.Infrastructure/
  {ServiceName}.Api/
  {ServiceName}.Contracts/
```

Subfolder examples:

- Domain: `Aggregates`, `Entities`, `ValueObjects`, `Events`, `Repositories`
- Application: `Abstractions`, `UseCases/Commands`, `UseCases/Queries`, `DTOs`, `Validators`
- Infrastructure: `Persistence/Configurations`, `Persistence/Migrations`, `Repositories`, `Integrations`
- Api: `Endpoints`, `Mapping`
- Contracts: `Requests`, `Responses`, `IntegrationEvents`

## Mandatory Dependency Rules

- `Domain` must not depend on Application, Infrastructure, Api, or other service internals.
- `Application` can depend on Domain and abstraction layers, not on Infrastructure/Api concrete implementations.
- `Infrastructure` can depend on Application/Domain and `Contracts`.
- `Api` can depend on Application and Contracts; direct Infrastructure implementations are avoided.
- `Contracts` must not depend on Domain/Application/Infrastructure internals.

## Test Placement

Use this folder baseline:

- `test/Unit/Services/{ServiceName}`
- `test/Integration/Services/{ServiceName}`
- `test/Contract/Services/{ServiceName}`

Domain/Application tests should be the first priority before wiring Infrastructure/Api and Gateway.

## Usage Pattern

1. Confirm `{ServiceName}` and service boundary in business terms.
2. Scaffold service layer folders and matching test folders.
3. Define Domain and Application contracts/handlers first.
4. Add Infrastructure and Api by request, keeping dependency direction.
5. Add Gateway/ Aspire linkage only after service contracts and tests are stable.

## Prohibited Changes

- Do not move internal Domain/Application types into `Contracts`.
- Do not route business logic through APIGateway.
- Do not skip unit/contract planning for new service APIs.

## Quick Checklist

- `ServiceName` uses domain language (`Orders`, `Identity`, `Inventory`), not transport names.
- Public API contract uses `*.Contracts`.
- Gateway and client callers access the service through `APIGateway`.

See [service-template.md](references/service-template.md).
