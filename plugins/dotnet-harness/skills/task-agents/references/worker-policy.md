# Worker Policy

## Phase 5 Worker Partition

Phase 5 worker partition:

- Phase 5 worker agents are `standard`/`deep` only; `lightweight` mode must not call `backend-worker`, `frontend-worker`, `test-worker`, or `docs-harness-worker`.
- Split long implementation into feature slices before spawning workers.
- Each feature slice must have one owner worker, allowed paths, forbidden paths, expected changes, validation evidence, and stop condition.
- Preferred workers: `backend-worker`, `frontend-worker`, `test-worker`, and `docs-harness-worker`.
- In `standard` and `deep`, use worker agents by default for non-trivial implementation when subagent tooling is available and the user has not explicitly opted out.
- Run feature workers in parallel by default when their write sets are disjoint, public contracts are stable, migrations are absent, package/solution files are not shared, and validation can run independently.
- Run feature workers serially when slices share files, contracts, migrations, package files, solution files, runtime state, release state, or unresolved decisions.
- Main thread or `implementation-coordinator` must report `Parallel: yes` or `Parallel: no` with the reason before Phase 5 starts. `Parallel: no` needs a concrete coupling, safety, fallback, or opt-out reason.
- If parallel workers finish with conflicting changes, stop new work and route to `implementation-coordinator` for merge order.

Phase 5 worker handoff must include feature slice name, owner worker, allowed paths, forbidden paths, parallel eligibility, serial order when needed, and validation evidence.

Workers`: feature worker agents, feature slice ownership, parallel eligibility, and serial order when needed.
