---
name: project-structure-setup
description: Scaffold architecture folders for an Aspire-based project with an interactive project name fallback when not provided.
---

# Project Structure Setup

Use this skill when creating/recreating baseline folders for a project based on a fixed architecture layout.

## What it builds

- `src/Aspire/{AppHost,ServiceDefaults}`
- `src/FrontEnd/{Web,Web.Client}`
- `src/BackEnd/APIGateway`
- `src/BackEnd/BuildingBlocks/{Contracts,Messaging,Observability}`
- `test/{Architecture,Unit,Integration,Contract,Functional/{APIGateway,FrontEnd},EndToEnd}`

## Service scaffold (optional)

If enabled for `{ServiceName}`:

- `src/BackEnd/Services/{ServiceName}/{ServiceName}.{Domain,Application,Infrastructure,Api,Contracts}`
- `test/{Unit,Integration,Contract}/Services/{ServiceName}`

## Prompts

- Prompts are interactive only when `--project-name` or `--service-name` are omitted.
- User-facing prompt text is Korean.
- If `ProjectName` is empty, it is requested again.
- If `ServiceName` is empty, service folders are skipped.

## CLI

```bash
python scripts/bootstrap_project_structure.py --root .
python scripts/bootstrap_project_structure.py --root . --project-name MyProj
python scripts/bootstrap_project_structure.py --root . --project-name MyProj --service-name Orders
python scripts/bootstrap_project_structure.py --root . --project-name MyProj --service-name Orders --preview
```

## Rules

- Create directories and `.gitkeep` files only.
- `.gitkeep` is enabled by default; use `--no-gitkeep` to skip.
- Never delete existing directories.
- No code/template generation.

See [scripts/bootstrap_project_structure.py](scripts/bootstrap_project_structure.py) and [references/project-structure.md](references/project-structure.md).
