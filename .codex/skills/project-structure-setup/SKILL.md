---
name: project-structure-setup
description: Scaffold architecture folders for an Aspire-based project with an interactive project name fallback when not provided.
---

# Project Structure Setup

Use when creating/recreating baseline folders from fixed architecture layout.

## What it builds

- `src/Aspire/{AppHost,ServiceDefaults}`
- `src/FrontEnd/{Web,Web.Client}`
- `src/BackEnd/APIGateway`
- `src/BackEnd/BuildingBlocks/{Contracts,Messaging,Observability}`
- `test/{Architecture,Unit,Integration,Contract,Functional/{APIGateway,FrontEnd},EndToEnd}`
- `docs/Project/README.md` with the baseline structure summary

## Service scaffold (optional)

If `{ServiceName}` enabled:

- `src/BackEnd/Services/{ServiceName}/{ServiceName}.{Domain,Application,Infrastructure,Api,Contracts}`
- `test/{Unit,Integration,Contract}/Services/{ServiceName}`

## Prompts

- Prompts interactive only when `--project-name` or `--service-name` omitted.
- User-facing prompt text is Korean.
- If `ProjectName` empty, request again.
- If `ServiceName` empty, skip service folders.

## CLI

```bash
python scripts/bootstrap_project_structure.py --root .
python scripts/bootstrap_project_structure.py --root . --project-name MyProj
python scripts/bootstrap_project_structure.py --root . --project-name MyProj --service-name Orders
python scripts/bootstrap_project_structure.py --root . --project-name MyProj --service-name Orders --preview
```

## Rules

- Create only directories + `.gitkeep` files.
- Create `docs/Project/README.md` if it does not exist.
- `.gitkeep` enabled by default; use `--no-gitkeep` to skip.
- Never delete existing directories.
- Do not overwrite an existing `docs/Project/README.md`.
- No code generation.

See [scripts/bootstrap_project_structure.py](scripts/bootstrap_project_structure.py) and [references/project-structure.md](references/project-structure.md).
