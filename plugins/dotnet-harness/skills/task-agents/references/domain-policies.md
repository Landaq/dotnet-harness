# Domain Policies

This file replaces the former standalone helper skills:

- `architecture-workflow-guardrails`
- `service-template-setup`
- `frontend-ui-policy`
- `tdd-test-workflow`
- `reference-comparison-audit`

Use this reference with `dotnet-harness:task-agents` and discovered repo-local agents.

## Workflow Guardrails

Use before implementation when a request touches a feature, cross-layer refactor, service boundary, API/Gateway/FrontEnd/Aspire workflow, release, scaffold, or high-risk change.

- Complex work threshold: 13%.
- Backend work threshold: 5%.
- Frontend work threshold: 5%.
- If ambiguity is above threshold, ask max 3 questions before code.
- Number questions and mark recommendation with `(Recommended)`.
- Recalculate ambiguity after each user answer.
- No implementation until ambiguity is below threshold.
- No destructive Git without explicit user request.
- Migration, secret handling, destructive cleanup, commit, push, merge need explicit consent.
- Do not create plan files by default; create a named plan artifact only when the user explicitly asks for one.
- Include verification commands and risk list before execution.

## Service Template

Use when adding, reviewing, or refactoring a service under `src/BackEnd/Services/{ServiceName}`.

Canonical layout:

```text
src/BackEnd/Services/{ServiceName}/
  {ServiceName}.Domain/
  {ServiceName}.Application/
  {ServiceName}.Infrastructure/
  {ServiceName}.Api/
  {ServiceName}.Contracts/
```

Dependency rules:

- `Domain` must not depend on Application, Infrastructure, Api, or other service internals.
- `Application` can depend on Domain and abstractions, not Infrastructure/Api concrete implementations.
- `Infrastructure` can depend on Application/Domain and Contracts.
- `Api` can depend on Application and Contracts; direct Infrastructure implementations are avoided.
- `Contracts` must not depend on Domain/Application/Infrastructure internals.

Service creation order:

1. Confirm `{ServiceName}` and business boundary.
2. Create domain-level tests for core rules.
3. Build Domain and Application before Infrastructure/Api.
4. Add contract tests for request/response/integration event.
5. Add Gateway route and Aspire registration at integration stage.

MSA readiness gate: public contracts isolated, service data ownership clear, no cross-service internal type use, external calls through Gateway/AppHost wiring.

## Frontend UI

- MudBlazor is the default library for standard screens.
- DevExpress only for BI-level screens: dashboard, advanced grid, pivot-like analysis, reporting, charts, export-heavy pages.
- No DevExpress for simple CRUD without explicit reason.
- DevExpress baseline `23.2.x` unless approved otherwise.
- Prefer `InteractiveAuto`.
- Put global interactive/page UI in `src/FrontEnd/Web.Client` unless server-only need requires `src/FrontEnd/Web`.
- Keep `Web.Client` browser-safe and secret-free.
- No secrets, server SDKs, DB access, or server-only deps in `Web.Client`.
- API calls go through `APIGateway`.
- Prefer `test/Functional/FrontEnd` checks for render mode, forms, and API interaction.

When applying UI changes, report project choice, component choice with reason, render mode and safety checks, API path and contract impact, and functional test updates.

## TDD And Testing

Use `Red -> Green -> Refactor` for every feature.

Layer order:

1. Unit: Domain/Application rules and handlers.
2. Contract: service contracts and integration events.
3. Integration: EF Core mapping, persistence adapters, external collaborators.
4. Functional: API Gateway, endpoints, frontend flows.
5. Architecture: dependency direction and naming.
6. End-to-end: release-grade scenarios.

Test folder mapping:

- Unit: `test/Unit/Services/{ServiceName}`
- Integration: `test/Integration/Services/{ServiceName}`
- Contract: `test/Contract/Services/{ServiceName}`
- Functional/APIGateway: `test/Functional/APIGateway`
- Functional/FrontEnd: `test/Functional/FrontEnd`
- Architecture: `test/Architecture`
- EndToEnd: `test/EndToEnd`

Development discipline: propose failing tests before implementation, keep implementation minimal, refactor only after each layer is green, and protect architecture rules while refactoring.

## Reference Comparison

Use when reviewing architecture direction or adopting structural change.

- Discover solution dynamically; prefer one active `.slnx`.
- Keep root `global.json`, `Directory.Build.props`, and `Directory.Packages.props`.
- Preserve Aspire/AppHost, ServiceDefaults, Gateway, and FrontEnd split.
- `ServiceDefaults` = observability/discovery/resilience defaults only.
- Gateway = routing/security/transform/telemetry, not business logic.
- Contracts/public models are isolated from Domain models.
- Service structure aligns to bounded contexts.
- Tests/projects map to service boundaries.
- Dependency direction: Domain -> Application -> Infrastructure/Api -> Gateway/Web/Aspire.
- No cross-service internal type use.
- API routes/contracts explicit and version-aware.

Output: missing baseline files/rules, recommended changes with impact, smallest safe apply order, validation list, and apply/defer decisions with rationale.
