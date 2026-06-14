# Review Policy

## Feature-Slice Review

Review must be scoped by feature slice. A reviewer handoff must include:

- feature slice name;
- reviewer perspective;
- allowed paths;
- forbidden paths;
- changed files or diff scope;
- success criteria;
- unresolved risks;
- validation evidence;
- stop condition.

Do not ask every reviewer to inspect the whole diff. Use one broad `code-reviewer` only when the change is one slice, when a whole-diff defect scan is explicitly needed, or when no perspective reviewer matches.

## Reviewer Perspectives

Use the smallest reviewer set that covers real risk:

- `backend-reviewer`: backend, API, domain, EF Core, Aspire, YARP, SQL Server, Redis, service registration.
- `frontend-reviewer`: Blazor, Web.Client, MudBlazor, UI state, rendering mode, component boundaries.
- `test-reviewer`: tests, validation evidence, regression surface, smoke commands, missing focused scenarios.
- `docs-harness-reviewer`: plugin, skill, agent, script, scaffold template, install/upgrade, README, release notes.
- `code-reviewer`: broad defect scan when the whole change is one slice or cross-slice behavior needs one final pass.
- `reference-auditor`: external API/library/framework contract or architecture-reference risk.

## Parallel Review

Reviewer agents are read-only by default.

Run reviewers in parallel when:

- each reviewer has a bounded feature slice or distinct perspective;
- no reviewer output changes another reviewer's input contract;
- review does not require edit ownership;
- validation evidence already exists or is independently runnable.

Serialize reviewers when:

- one reviewer must decide the contract another reviewer checks;
- review findings may require implementation changes before the next perspective matters;
- the same files are reviewed for the same concern;
- the handoff lacks clear changed files, success criteria, or validation evidence.

## Output

Reviewer output must use the compressed return contract:

```text
Findings:
Changes:
Risks:
Verify:
Next:
```

`Findings` must be actionable and scoped to the assigned feature slice. `Next` must be input for the next stage, not completion proof.
