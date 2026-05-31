# Frontend UI Guidelines Reference

- MudBlazor is the default UI library for 일반 업무 화면.
- DevExpress Blazor is reserved for BI scenarios (dashboard, pivot, rich chart, export-heavy reporting).
- Keep DevExpress to 23.2.x stream unless explicitly approved.
- `Web.Client` should not contain server secrets or DB access.
- Default rendering posture: evaluate `InteractiveAuto` first, then refine by page.

Mandatory checks:

- choose target project: `Web` or `Web.Client`
- choose render mode: Static/Interactive Server/WASM
- enforce API access through gateway and contracts
- include functional tests for rendering and validation behavior
