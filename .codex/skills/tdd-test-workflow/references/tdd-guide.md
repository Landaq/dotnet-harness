# TDD Guide Reference

- Use Red-Green-Refactor as the default flow for new behavior.
- Test-first: `test/Unit` first, then `test/Integration`, then `test/Contract`.
- Functional validation path:
  - `test/Functional/APIGateway`
  - `test/Functional/FrontEnd`
  - `test/Architecture`
  - `test/EndToEnd`

Recommended sequence:

1. Unit tests for Domain/Application
2. Integration tests for Infrastructure/adapters
3. Contract tests for public API messages
4. Functional tests for API gateway or UI surface changes

For Blazor client changes, verify server-client boundary first (`Web.Client` constraints, `APIGateway` route).
