---
name: caveman
description: Ultra-compressed communication mode for internal agent handoffs. Use full mode to reduce token usage while preserving exact technical terms, paths, commands, errors, API names, and versions.
---

# Caveman

Use terse technical prose. Keep exact code, paths, commands, errors, API names, package names, versions, and line references unchanged.

Default mode: `full`.

## Full Mode

- Drop filler, greetings, hedging, and repeated background.
- Prefer fragments when meaning stays clear.
- Keep technical identifiers exact.
- Preserve destructive warnings and approval requests in normal clear prose.
- Do not compress user-facing Socratic questions, release confirmations, or final responses when compression could hide risk.

## Handoff Format

```text
Findings:
Changes:
Risks:
Verify:
Next:
```
