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

Ambiguity scoring rubric:

- Score ambiguity from concrete unresolved blockers, not model confidence.
- Start at 0%. Add the highest applicable points from each category, then cap at 100%.
- Business goal: add 0% when the user states the goal and non-goal; 5% when the goal is clear but non-goals are missing; 15% when the desired outcome is broad or mixed.
- Input/output specification: add 0% when target files, APIs, screens, commands, or data contracts are named; 5% when the target surface is inferable from repo context; 15% when the target surface or expected output is not named.
- Persistence/data/runtime rules: add 0% when no data/runtime state is involved or the rule is explicit; 5% when storage, migration, cache, auth, or runtime state impact is likely but bounded; 15% when data ownership, migration, secret, auth, or production/runtime state is unclear.
- Validation evidence: add 0% when the user or repo provides a concrete validation command; 5% when the smallest proof is inferable; 10% when no meaningful verification route is known.
- Approval/release/git boundary: add 0% when no approval-sensitive action is needed or the user explicitly requested it; 10% when destructive, git, release, branch/worktree, migration, secret, or production access may be needed but is not approved.
- `Socratic: satisfied` is allowed only when every active blocker category is at 0% or the remaining nonzero ambiguity is explicitly moved to Out Of Scope or Todo.
- Recalculate after each user answer by naming which categories changed; do not lower the score only because the model feels confident.

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

- MudBlazor is the default library for standard screens when no project override exists.
- DevExpress is optional and only for BI-level screens by default: dashboard, advanced grid, pivot-like analysis, reporting, charts, export-heavy pages.
- No DevExpress for simple CRUD without explicit reason or project override.
- DevExpress baseline `23.2.x` unless approved otherwise or overridden by project configuration.
- Before enforcing UI library rules, inspect `.codex/harness-config.json` when present.
- If `.codex/harness-config.json` declares `ui.defaultLibrary`, `ui.biLibrary`, or `ui.devExpressVersion`, follow that project config and report the override.
- Supported default-library examples include `MudBlazor`, `FluentUI`, `BlazorBuiltIn`, and `TailwindOnly`; unknown values require a short clarification before UI implementation.
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
