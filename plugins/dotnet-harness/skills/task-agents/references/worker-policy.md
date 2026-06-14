# Worker Policy

## Phase 7 Worker Partition

Worker agents run only after:

1. Socratic clarification is satisfied;
2. average ambiguity is `<= 8%`;
3. Goal Boundary Confirmation defines goal, non-goals, success criteria, allowed paths, forbidden paths, validation, git, TaskResult, and risk gates;
4. runtime delegation permission is present;
5. Agent Route Planning decides serial or parallel execution.

Worker partition:

- Worker agents are `standard`/`deep` only; `lightweight` mode must not call `backend-worker`, `frontend-worker`, `test-worker`, or `docs-harness-worker`.
- Split long implementation into feature slices before spawning workers.
- Each feature slice must have one owner worker, allowed paths, forbidden paths, expected changes, validation evidence, and stop condition.
- Preferred workers: `backend-worker`, `frontend-worker`, `test-worker`, and `docs-harness-worker`.
- In `standard` and `deep`, use worker agents only after clarification is satisfied, runtime delegation permission is present, and the user has not opted out.
- Run feature workers in parallel only when their write sets are disjoint, public contracts are stable, migrations are absent, package/solution files are not shared, runtime state is not shared, and validation can run independently.
- Run feature workers serially when slices share files, contracts, migrations, package files, solution files, runtime state, release state, or unresolved decisions.
- Main thread or `implementation-coordinator` must report `Parallel: yes` or `Parallel: no` with the reason before worker implementation starts.
- `Parallel: no` needs a concrete coupling, safety, fallback, host-policy, no-explicit-agent-request, or opt-out reason.
- If parallel workers finish with conflicting changes, stop new work and route to `implementation-coordinator` for merge order.

Worker handoff must include feature slice name, owner worker, allowed paths, forbidden paths, parallel eligibility, serial order when needed, and validation evidence.

`Workers`: feature worker agents, feature slice ownership, parallel eligibility, and serial order when needed.
