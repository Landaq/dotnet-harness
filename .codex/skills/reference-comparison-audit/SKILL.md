---
name: reference-comparison-audit
description: Compare current architecture decisions against external reference practices and produce concrete action items for missing standards.
---

# Reference Comparison Audit

Use when architecture/process need alignment check against established guidance.

## Audit scope

- Validate solution baseline (`Rev04.slnx`) active anchor.
- Verify root build governance:
  - `global.json`
  - `Directory.Build.props`
  - `Directory.Packages.props`
- Verify service boundary strategy (`Domain/Application/Infrastructure/Api/Contracts`) + future MSA readiness.
- Verify ServiceDefaults runtime-only: no domain models/infra business logic.
- Verify architecture-level dependency tests planned/present.

## Output format

1. Gap list: Missing / Partial / Compliant.
2. Concrete fix list: file-level or process-level changes.
3. Priority: High/Medium/Low + acceptance note.

## Decision guidance

- If gap affects solution stability, mark High + convert to explicit follow-up tasks.
- If only impl detail missing but direction stable, mark Medium.
- If aligned, mark Compliant with proof location.

## Reference anchors

- Keep read-only for planning. Apply file changes via project-structure/service/TDD/UI/workflow skills as follow-ups.
