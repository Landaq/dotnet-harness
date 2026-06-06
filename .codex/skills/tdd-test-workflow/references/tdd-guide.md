# TDD and Testing Strategy

- Use `Red -> Green -> Refactor` for every feature.
- Unit tests prioritize Domain and Application first.
- Integration tests validate Infrastructure (EF Core, adapter, external systems).
- Contract tests guard request/response models and integration events.
- Functional tests verify API Gateway and UI flows.
- Architecture tests verify dependency rules and naming boundaries.
- End-to-end tests run for release-grade scenarios.

## Test Folder Mapping

- Unit: `test/Unit/Services/{ServiceName}`
- Integration: `test/Integration/Services/{ServiceName}`
- Contract: `test/Contract/Services/{ServiceName}`
- Functional/APIGateway: `test/Functional/APIGateway`
- Functional/FrontEnd: `test/Functional/FrontEnd`
- Architecture: `test/Architecture`
- EndToEnd: `test/EndToEnd`

## Development Discipline

- Avoid implementing before failing tests are proposed.
- Keep implementation minimal to satisfy current test.
- Refactor only after each layer is green.
- Protect architecture rules while refactoring.
