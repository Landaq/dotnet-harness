---
name: service-template-setup
description: "Create or review a new backend service using dotnet-harness service-layer template rules, enforce Domain/Application/Infrastructure/Api/Contracts boundaries, and validate test placement."
---

# Service Template Setup

Use when adding/reviewing/refactoring service under `src/BackEnd/Services/{ServiceName}`.

## Scope

- Create service folders + optional test folders.
- Enforce DDD responsibilities + dependency direction.
- Public contracts stay in `Contracts`; infrastructure details stay in `Infrastructure`.
- Keep API/domain boundaries separate during scaffold planning.

## Canonical Service Layout

```text
src/BackEnd/Services/{ServiceName}/
  {ServiceName}.Domain/
  {ServiceName}.Application/
  {ServiceName}.Infrastructure/
  {ServiceName}.Api/
  {ServiceName}.Contracts/
```

Subfolder baseline:

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

Folder baseline:

- `test/Unit/Services/{ServiceName}`
- `test/Integration/Services/{ServiceName}`
- `test/Contract/Services/{ServiceName}`

Domain/Application tests first. Infrastructure/Api/Gateway wiring later.

## Usage Pattern

1. Confirm `{ServiceName}` and service boundary in business terms.
2. Scaffold layers + matching tests.
3. Define Domain and Application contracts/handlers first.
4. Add Infrastructure and Api by request; keep dependency direction.
5. Add Gateway/ Aspire linkage only after service contracts and tests are stable.

## Prohibited Changes

- No internal Domain/Application types in `Contracts`.
- No business logic in APIGateway.
- No new service API without unit/contract planning.

## Quick Checklist

- `ServiceName` uses domain language (`Orders`, `Identity`, `Inventory`), not transport names.
- Public API contract uses `*.Contracts`.
- Gateway and client callers access the service through `APIGateway`.

See [service-template.md](references/service-template.md).
