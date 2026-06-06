---
name: frontend-ui-policy
description: "Apply MudBlazor-first UI policy, BI option rules for DevExpress 23.2.x, and render-mode/boundary checks for Blazor Web and Web.Client."
---

# Frontend UI Policy

Use this skill when editing or creating Blazor UI for Rev04.

## UI Library Policy

- Use MudBlazor by default for business and CRUD screens.
- Use DevExpress Blazor only for BI-focused use cases (dashboard, advanced grid, pivot-like analysis, reporting, data export-heavy screens).
- Do not default to DevExpress for simple CRUD.
- DevExpress package lines are evaluated at `23.2.x` unless explicitly approved otherwise.

## Render and Boundary Rules

- Prefer `InteractiveAuto` as a starting strategy.
- Place global interactive/page-level UI in `src/FrontEnd/Web.Client` unless server-only functionality requires `src/FrontEnd/Web`.
- Never keep secrets, server SDKs, or DB access in `Web.Client`.
- API calls should pass through `APIGateway`.

## Frontend Checklist

- Specify target project (`Web` or `Web.Client`).
- Document component library decision and rationale.
- Confirm render mode impact (Static SSR / Interactive Server / Interactive WebAssembly / Auto).
- Confirm NuGet impact and version policy.
- Confirm API boundary and `test/Functional/FrontEnd` coverage.

## Forbidden Actions

- Do not introduce DevExpress in simple screens without explicit reason.
- Do not store license keys, feed credentials, or account data in source or docs.
- Do not place server-only dependencies in `Web.Client`.
- Do not access DB directly from client-side code.

## Output Template

When applying UI changes, report:
- project choice,
- component choice with reason,
- render mode and safety checks,
- API path and contract impact,
- functional test updates.

See [frontend-ui-guidelines.md](references/frontend-ui-guidelines.md).
