---
name: tdd-test-workflow
description: Apply test-first development flow for Rev04 services with Unit, Integration, Contract, Functional, Architecture, and EndToEnd test responsibilities.
---

# TDD Test Workflow

Use whenever feature impl starts and test sequence not fixed.

## Core loop

1. **Red**: write failing test encoding requirement.
2. **Green**: implement minimum code to pass.
3. **Refactor**: enforce boundaries + simplify after green.

## Required order for backend services

1. Domain test: Aggregate, value object, state transition, rule edge cases.
2. Application test: Command/Query + handlers.
3. Contract test: request/response + integration event contracts.
4. Infrastructure test: EF mappings, repositories, adapter integration.
5. Api test: endpoint behavior + status mapping.
6. Gateway/FrontEnd validation after service contracts stabilize.

## Test folder conventions

- `test/Unit/Services/{ServiceName}` for Domain/Application.
- `test/Integration/Services/{ServiceName}` for EF Core + external adapters.
- `test/Contract/Services/{ServiceName}` for public contract changes.
- `test/Functional/APIGateway` for route/auth/header behavior.
- `test/Functional/FrontEnd` for component + client interaction checks.
- `test/Architecture` for dependency + naming rules.
- `test/EndToEnd` for end-user scenarios.

## FrontEnd interaction rules

- For `Web.Client`, use browser-safe deps only.
- Put page/server concerns in `Web` when API proxy, secrets, or server-only features needed.
- Keep API boundary through `APIGateway`, then typed contract consumption or typed client.

## Completion checks

- Domain + Application tests exist before Infrastructure/Api completion.
- Contract changes include regression coverage.
- Add at least one architecture rule test for large structure changes.
- If request ambiguous, ask max 3 Korean follow-up questions before coding.
