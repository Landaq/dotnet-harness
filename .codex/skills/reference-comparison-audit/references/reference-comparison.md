# Architecture Reference Comparison

Checklist for aligning Rev04 decisions with common references:

- Use `.slnx` as source-of-truth solution file.
- Keep root `global.json`, `Directory.Build.props`, `Directory.Packages.props`.
- Preserve Aspire/AppHost, ServiceDefaults, Gateway, FrontEnd split.
- Move services toward explicit project boundaries when possible while maintaining compatibility.
- Add architecture tests for forbidden internal dependencies and contract coupling.
