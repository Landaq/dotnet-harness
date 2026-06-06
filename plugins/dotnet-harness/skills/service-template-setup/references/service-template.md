# Service Template Reference

## Purpose

`src/BackEnd/Services/{ServiceName}` represents one bounded-context unit and is structured for a future MSA split.

## Required Modules

- `{ServiceName}.Domain`
- `{ServiceName}.Application`
- `{ServiceName}.Infrastructure`
- `{ServiceName}.Api`
- `{ServiceName}.Contracts`

## Responsibility Rules

- Domain: only business model and rules.
- Application: use cases, handlers, DTOs, validators.
- Infrastructure: persistence and external adapters.
- Api: boundary adapters (Minimal API endpoints and mapping).
- Contracts: public request/response and integration event models.

## Dependency Direction

- Inward dependency only.
- `Application` should never depend on `Infrastructure`/`Api` concrete implementations.
- `Contracts` is for public types only, never internal implementations.

## Service Creation Steps

- Define service boundary and `{ServiceName}` first.
- Create domain-level tests for core rules.
- Build Domain and Application before Infrastructure/Api.
- Add contract tests for request/response/integration event.
- Add Gateway route and Aspire registration at the integration stage.

## MSA Readiness Gate

- Public contracts isolated.
- Data ownership per service and migration boundary.
- No direct reference to internal implementations across services.
- External calls enter through Gateway and AppHost wiring.
