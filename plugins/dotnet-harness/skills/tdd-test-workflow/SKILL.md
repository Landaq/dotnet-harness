---
name: tdd-test-workflow
description: "Apply Red-Green-Refactor for all feature work, assign tests by layer, and keep dependency checks before implementation."
---

# TDD Test Workflow

Use for backend, infrastructure, API, or frontend flow changes.

## Core Rule

Always `Red` -> `Green` -> `Refactor` before next layer.

## Layer Order

1. Unit: Domain/Application rules + handlers.
2. Contract: service contracts + integration events.
3. Integration: EF Core mapping, persistence adapters, external collaborators.
4. Functional: API Gateway, endpoints, frontend flows.
5. Architecture: dependency direction + naming.
6. End-to-end: release-level scenarios.

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

- Domain/Application no Infrastructure/Api concrete deps.
- Unit tests fast + deterministic.
- Contract tests protect interface stability, even in monolith mode.
- Never mix multiple layer changes in one untested step.

## Frontend Test Checks

- `Web.Client`: browser-safe deps only.
- `Web`: server-only concerns.
- API calls through `APIGateway` contract path.

## Request Template

When a user requests coding, confirm:

- target service (`ServiceName`)
- test levels to verify (unit, integration, contract, functional, architecture)
- API contract and route change scope

Then proceed with test-first implementation.

See [tdd-guide.md](references/tdd-guide.md).
