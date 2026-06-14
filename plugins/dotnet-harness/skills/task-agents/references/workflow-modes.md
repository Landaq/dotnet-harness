# Workflow Modes

Select one workflow mode before routing:

- `lightweight`: default for trivial or small tasks. Use for direct answers, status checks, narrow one-file fixes, mechanical doc edits, or low-risk validation. Ask at most one clarification question. Keep phase contracts internal unless a gate fails. Do not spawn worker agents. Final reporting is short: Socratic status, ambiguity if asked, changes, verification, delegation status, git status, and TaskResult status.
- `standard`: default for non-trivial work. Start with Requirement Intake, Socratic Clarification, Ambiguity Recalculation, and Goal Boundary Confirmation. Call only agents that are needed after clarification passes and runtime delegation permission is present. Worker agents are allowed only when requirements are settled. Parallel workers are allowed only for independent feature slices.
- `deep`: use when the user explicitly asks for deep review/planning, or when the task is release-sensitive, scaffold-changing, architecture-changing, high-risk, destructive-adjacent, security/auth/data-sensitive, or has unclear acceptance boundaries. Use the full Socratic checkpoint, ambiguity recalculation until average ambiguity is `<= 8%`, full handoff gates, review, and verification reporting.

Mode selection rules:

- Trivial or small work -> `lightweight`.
- Non-trivial work -> `standard`.
- Explicit deep/release/scaffold/architecture/high-risk work -> `deep`.

Mode reporting:

- In `lightweight`, ambiguity percentage may stay internal unless a gate blocks progress or the user asks.
- In `standard` and `deep`, report ambiguity before/after Socratic clarification, average ambiguity, goal alignment, and next stage before handoff.
- In `deep`, also report phase contracts, input/output contracts, and handoff gates.
- If the selected mode changes mid-task, state the old mode, new mode, and reason before continuing.

Mode-specific final reporting:

- `lightweight`: include `Socratic`, `Ambiguity` when relevant, `Agents Used`, `Agents Skipped`, `Main Thread Work`, `Review/Verification Evidence`, `Files Changed`, `Git`, and `TaskResult` only. Omit full phase and handoff tables unless a gate failed.
- `standard`: include concise phase summary, Socratic status, ambiguity before/after, delegation permission, selected agents, skipped agents, worker eligibility, verification evidence, changed files, git status, and TaskResult status.
- `deep`: include full phase/input/output/handoff-gate reporting, Socratic status, ambiguity recalculation, goal alignment, worker partition, review findings, verification evidence, changed files, git status, and TaskResult status.
