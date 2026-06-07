---
name: frontend-ui-policy
description: "Apply MudBlazor-first UI policy, BI option rules for DevExpress 23.2.x, and render-mode/boundary checks for Blazor Web and Web.Client."
---

# Frontend UI Policy

Use for Blazor UI edit/create.

## UI Library Policy

- MudBlazor default for business/CRUD.
- DevExpress only for BI: dashboard, advanced grid, pivot-like analysis, reporting, export-heavy screens.
- No DevExpress for simple CRUD without explicit reason.
- DevExpress baseline `23.2.x` unless approved otherwise.

## Render and Boundary Rules

- Prefer `InteractiveAuto`.
- Put global interactive/page UI in `src/FrontEnd/Web.Client` unless server-only need requires `src/FrontEnd/Web`.
- No secrets, server SDKs, DB access in `Web.Client`.
- API calls go through `APIGateway`.

## Frontend Checklist

- Target project: `Web` or `Web.Client`.
- Component library + reason.
- Render mode impact: Static SSR / Interactive Server / Interactive WebAssembly / Auto.
- NuGet impact + version policy.
- API boundary + `test/Functional/FrontEnd` coverage.

## Forbidden Actions

- No DevExpress in simple screens without explicit reason.
- No license keys, feed credentials, account data in source/docs.
- No server-only deps in `Web.Client`.
- No direct DB access from client code.

## Output Template

When applying UI changes, report:
- project choice,
- component choice with reason,
- render mode and safety checks,
- API path and contract impact,
- functional test updates.

See [frontend-ui-guidelines.md](references/frontend-ui-guidelines.md).
