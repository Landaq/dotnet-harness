---
name: reference-comparison-audit
description: Compare current architecture decisions against external reference practices and produce concrete action items for missing standards.
---

# Reference Comparison Audit

Use this skill when architecture or process needs alignment checks against established guidance.

## Audit scope

- Validate solution baseline (`Rev04.slnx`) is the active anchor.
- Verify root build governance:
  - `global.json`
  - `Directory.Build.props`
  - `Directory.Packages.props`
- Verify service boundary strategy (`Domain/Application/Infrastructure/Api/Contracts`) and future MSA readiness.
- Verify ServiceDefaults scope stays runtime-only (no domain models/infra business logic).
- Verify architecture-level dependency tests are planned or present.

## Output format

1. Gap list (Missing / Partial / Compliant)
2. Concrete fix list (file-level or process-level changes)
3. Priority (High/Medium/Low) and acceptance note

## Decision guidance

- If a gap affects solution stability, mark as high and convert into explicit follow-up tasks.
- If only implementation detail is missing but direction is stable, mark as medium.
- If aligned, mark as compliant with proof location.

## Reference anchors

- Keep this skill read-only to planning; apply file changes via project-structure/service/TDD/UI/workflow skills as follow-ups.
