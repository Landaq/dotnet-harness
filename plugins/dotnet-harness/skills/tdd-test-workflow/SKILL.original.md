---
name: tdd-test-workflow
description: Apply test-first development flow for .NET services with Unit, Integration, Contract, Functional, Architecture, and EndToEnd test responsibilities.
---

# TDD Test Workflow

Use this skill whenever feature implementation starts and test sequence is not yet fixed.

## Core loop

1. **Red**: write a failing test that encodes the requirement.
2. **Green**: implement the minimum code to pass.
3. **Refactor**: enforce boundaries and simplify after green.

## Required order for backend services

1. Domain test (Aggregate, value object, state transition, rule edge cases)
2. Application test (Command/Query and handlers)
3. Contract test (request/response and integration event contracts)
4. Infrastructure test (EF mappings, repositories, adapter integration)
5. Api test (endpoint behavior and status mapping)
6. Gateway/FrontEnd validation after service contracts stabilize

## Test folder conventions

- `test/Unit/Services/{ServiceName}` for Domain/Application
- `test/Integration/Services/{ServiceName}` for EF Core and external adapters
- `test/Contract/Services/{ServiceName}` for public contract changes
- `test/Functional/APIGateway` for route/auth/header behavior
- `test/Functional/FrontEnd` for component and client interaction checks
- `test/Architecture` for dependency and naming rules
- `test/EndToEnd` for end-user scenarios

## FrontEnd interaction rules

- For `Web.Client`, use browser-safe dependencies only.
- Place page/server concerns in `Web` when API proxy, secrets, or server-only features are needed.
- Keep API boundary through `APIGateway`, then typed contract consumption or typed client.

## Completion checks

- Domain and Application tests exist before Infrastructure/Api completion.
- Contract changes include regression coverage.
- At least one architecture rule test is added when large structure changes occur.
- If the request is ambiguous, ask up to 3 follow-up Korean questions to narrow scope before coding.
