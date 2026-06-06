# Frontend UI Policy Reference

- MudBlazor is the default library for standard screens.
- DevExpress is optional and reserved for BI-level screens:
  - dashboard, advanced grid, pivot-like analysis, reporting, charts, export-heavy pages.
- Keep `Web.Client` browser-safe and secret-free.
- Use `InteractiveAuto` with per-page overrides for SSR or server-only screens.
- Prefer `test/Functional/FrontEnd` checks for render mode, forms, and API interaction.
