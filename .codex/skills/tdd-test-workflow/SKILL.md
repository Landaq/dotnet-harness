---
name: tdd-test-workflow
description: "Apply Red-Green-Refactor for all feature work, assign tests by layer, and keep dependency checks before implementation."
---

# TDD Test Workflow

Use this skill when implementing functionality for backend, infrastructure integration, API, or frontend flow changes.

## Core Rule

Always start with `Red`, then implement `Green`, then perform `Refactor` before moving to next layer.

## Layer Order

1. Unit tests: Domain/Application business rules and handlers.
2. Contract tests: service contracts and integration events.
3. Integration tests: EF Core mappings, persistence adapters, and external collaborators.
4. Functional tests: API Gateway, API endpoints, and frontend flow behavior.
5. Architecture tests: dependency direction and naming constraints.
6. End-to-end checks for release-level scenarios.

## Required Test Folders

```text
test/Unit/Services/{ServiceName}
test/Integration/Services/{ServiceName}
test/Contract/Services/{ServiceName}
test/Functional/APIGateway
test/Functional/FrontEnd
test/Architecture
test/EndToEnd
```

## Backend Feature Sequence

1. Domain aggregate and rule tests.
2. Application use-case tests.
3. Contract and DTO/event tests.
4. Infrastructure integration checks.
5. Api boundary tests.
6. Gateway and Aspire wiring tests.
7. Frontend/API client wiring verification.

## Working Rules

- Domain/Application must not depend on Infrastructure/Api concrete implementations.
- Unit tests should be fast and deterministic.
- Contract tests protect interface stability even when services stay in monolith mode.
- Never mix multiple layer changes in a single untested step.

## Frontend Test Checks

- `Web.Client` only uses browser-safe dependencies.
- `Web` handles server-only concerns.
- API calls should go through `APIGateway` contract-based path.

## Request Template

When a user requests coding, confirm:

- target service (`ServiceName`)
- test levels to verify (unit, integration, contract, functional, architecture)
- API contract and route change scope

Then proceed with test-first implementation.

See [tdd-guide.md](references/tdd-guide.md).
