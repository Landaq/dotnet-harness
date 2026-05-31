---
name: frontend-ui-policy
description: "Enforce Blazor FrontEnd UI policy: MudBlazor-first implementation and DevExpress-only for BI-related scopes with clear rendering-mode decisions."
---

# Frontend UI Policy

Use this skill before choosing frontend components or implementing Blazor UI changes.

## Default selection policy

- Use `MudBlazor` first for general CRUD, layout, forms, dialogs, and validation-heavy pages.
- Consider `DevExpress Blazor 23.2.x` only when BI-oriented requirements are explicit (dashboard, pivot/grid analytics, advanced export/reporting workflows).
- Never default to DevExpress for simple CRUD pages.

## Rendering boundaries

- Target `InteractiveAuto` as first option, then adjust page-by-page.
- `Web.Client` should hold client-safe components.
- `Web` should hold server-only pages and server-side service setup when required.
- Never place secrets, server SDKs, or DB access in `Web.Client`.

## DevExpress usage guardrails

- Use only when approved.
- Keep version line aligned to 23.2.x unless explicitly changed.
- Do not commit license keys, feed credentials, or private account data.

## Implementation checklist

- Confirm `ProjectName`, target project (`Web` vs `Web.Client`), render mode, and API path strategy.
- Verify component choice rationale (`MudBlazor` vs `DevExpress`) is documented.
- Suggest `Functional/FrontEnd` checks for render behavior, validation, and API interaction.
- Ask clarifying questions in Korean when library/BI intent is unclear.
