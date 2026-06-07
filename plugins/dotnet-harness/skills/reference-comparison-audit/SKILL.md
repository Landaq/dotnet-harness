---
name: reference-comparison-audit
description: "Run an architecture audit against external references and lock baseline decisions such as .slnx usage, centralized build props, service boundaries, and contract-first design."
---

# Reference Comparison Audit

Use when reviewing architecture direction or adopting structural change.

## Baseline checks

- Discover solution dynamically; prefer one active `.slnx`.
- Recommend central build/package policy:
  - `global.json`
  - `Directory.Build.props`
  - `Directory.Packages.props`
- Service structure aligns to bounded contexts.
- `ServiceDefaults` = observability/discovery/resilience defaults only.
- Gateway = routing/security/transform/telemetry, not business logic.
- Contracts/public models isolated from Domain models.

## Service Boundary Audit

- Tests/projects map to service boundaries.
- Dependency direction: Domain -> Application -> Infrastructure/Api -> Gateway/Web/Aspire.
- No cross-service internal type use.
- API routes/contracts explicit + version-aware.

## Output Structure

1. Missing baseline files/rules.
2. Recommended changes with impact.
3. Smallest safe apply order.
4. Validation list: build/test/lint + architecture checks.

## Delivery Template

- "Comparison result: pass/fail by rule"
- "Required corrections"
- "Apply now or defer" decisions with rationale

See [reference-comparison.md](references/reference-comparison.md).
