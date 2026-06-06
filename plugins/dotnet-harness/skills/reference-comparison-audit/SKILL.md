---
name: reference-comparison-audit
description: "Run an architecture audit against external references and lock baseline decisions such as .slnx usage, centralized build props, service boundaries, and contract-first design."
---

# Reference Comparison Audit

Use this skill when reviewing architecture direction or before adopting a new structural change.

## Baseline checks

- Enforce `Rev04.slnx` as the repository solution standard.
- Recommend central build and package policy files:
  - `global.json`
  - `Directory.Build.props`
  - `Directory.Packages.props`
- Validate service structure aligns with bounded context boundaries.
- Keep `ServiceDefaults` limited to observability/discovery/resilience defaults.
- Keep Gateway focused on routing/security/transform/telemetry and not business logic.
- Validate contract/public model isolation from Domain models.

## Service Boundary Audit

- Confirm test/projects map to service boundaries.
- Confirm dependency direction checks (Domain -> Application -> Infrastructure/Api -> Gateway/Web/Aspire).
- Confirm no cross-service internal type usage.
- Confirm API routes and contracts are explicit and version-aware.

## Output Structure

1. List of missing baseline files/rules.
2. Recommended changes with impact.
3. Suggested order to apply in smallest safe slices.
4. Validation list (build/test/lint + architecture checks).

## Delivery Template

- "Comparison result: pass/fail by rule"
- "Required corrections"
- "Apply now or defer" decisions with rationale

See [reference-comparison.md](references/reference-comparison.md).
