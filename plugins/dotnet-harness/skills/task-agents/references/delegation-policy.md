# Delegation Policy

## Agent Execution Contract

Task Agents must clarify before delegating. Actual subagent execution begins only after Socratic goal clarification is satisfied and runtime delegation permission is present.

Actual subagent execution means calling an available delegated-agent tool such as `spawn_agent` or the environment's equivalent subagent runner.

Delegation permission values:

- `explicit`: user used `$dotnet-harness`, `task-agents`, `/feedback`, `에이전트`, `subagent`, `서브에이전트`, `에이전트에게 맡겨`, `작업을 에이전트들이 수행`, or equivalent wording.
- `not explicit`: user asked for implementation/refactor/review/validation without agent wording.
- `user-opt-out`: user said `에이전트 쓰지마`, `no agents`, `skip agents`, `직접 해줘`, `메인에서 직접 해줘`, `빠르게 메인에서 해줘`, `main thread only`, or equivalent wording.
- `host-policy`: runtime policy permits or blocks default subagent execution.
- `unavailable`: no delegated-agent tool is callable.

Execution rules:

- Do not spawn worker subagents before Socratic clarification is satisfied and average ambiguity is `<= 8%`.
- Before fallback, inspect active callable tools.
- Do not report `Agent execution fallback: unavailable` while such a tool is callable.
- Do not report `Agent execution fallback: unavailable` while `spawn_agent`, `delegate_task`, `run_agent`, or an equivalent delegated-agent tool is callable.
- If the user explicitly authorized agents and tooling is available, use subagent handoff after clarification.
- If the user did not explicitly authorize agents and runtime policy requires explicit authorization, do not spawn. Ask briefly whether to delegate to agents, or report `Delegation: skipped no-explicit-agent-request` and proceed main-thread direct after clarification.
- If runtime policy allows default subagent execution without explicit authorization, use subagent handoff after clarification for non-trivial work.
- Do not spawn subagents for trivial one-file edits, direct user questions, explicit user opt-out, unsafe delegation, or work whose next step is fully blocked on one local decision.
- Reading agent TOML, summarizing an agent persona, or role-playing a specialist in the main thread does not count as subagent execution.
- Use `dotnet-harness:*` plugin skills as the skill contract inside the delegated prompt.
- Keep the main thread responsible for scope, approvals, final integration, file ownership, and final answer.
- Reject plans that only read TOML files, summarize personas, or simulate specialist reasoning in the main thread.
- A delegation plan is not delegation evidence.

For non-trivial work, stop before implementation until Socratic clarification is satisfied and either a delegated-agent tool-call receipt exists, runtime policy blocks actual delegation, user authorization is missing under explicit-auth policy, or fallback is proven by tool availability check.

Delegated prompt must include:

1. selected role name;
2. active goal and non-goals;
3. allowed paths and forbidden paths;
4. expected output or changed file list;
5. validation command or evidence requirement;
6. instruction to avoid git operations unless the role is `git-operator` and the user explicitly requested git work.

## Delegation Evidence

When subagent tooling is available, allowed, and used, Task Agents output must include `Delegation: used` before or during implementation:

```text
Delegation: used
Callable Namespace:
Tool:
Tool availability checked:
Tool Call Receipt:
Tool Result Status:
Agent:
Role:
Purpose:
Status:
Result Used:
```

If the environment has no usable subagent tool, output both:

```text
Agent execution fallback: unavailable
Tool availability checked:
Delegation: skipped unavailable
```

If explicit authorization is missing and runtime policy requires it, output:

```text
Delegation Permission: not explicit
Runtime Policy: explicit authorization required
Delegation: skipped no-explicit-agent-request
```

`Delegation: used` is valid only when backed by an actual tool-call receipt visible in the transcript. Do not synthesize this block from a delegation plan.

Do not mark utilization satisfied from planned delegation, simulated agent reasoning, or reading `.codex/agents/*.toml`.

No-spawn decisions must include the exact reason.

Valid no-agent reasons are `trivial`, `blocked`, `coupled`, `user-opt-out`, `unavailable`, `unsafe`, `host-policy`, or `no-explicit-agent-request`.

## Compressed Agent Handoff

Use `caveman full` only for internal subagent handoff prompts and subagent return summaries.

Do not use `caveman full` for user-facing Socratic questions.

Compressed handoffs must preserve exact file paths, commands, errors, API names, package names, versions, agent names, skill names, and line references.

Internal handoff prompt format:

```text
Mode: caveman full
Prior result accepted:
Role:
Goal:
Non-goals:
Allow:
Deny:
Need:
Verify:
No git unless explicit.
Return:
Findings:
Changes:
Risks:
Verify:
Next:
```

Internal subagent return format:

```text
Findings:
Changes:
Risks:
Verify:
Next:
```

Subagent output as next input:

- Main thread must treat `Findings`, `Changes`, `Risks`, `Verify`, and `Next` as the next stage input, not as final truth.
- Previous agent output is clear only when it includes: role, scope, `Findings`, `Changes`, `Risks`, `Verify`, `Next`, affected paths, and open questions or `none`.
- Do not hand off to the next agent until previous agent output is explicit, bounded, and usable as the next input contract.
- Each handoff prompt must start with `Prior result accepted:` plus short caveman summary of the previous agent result and any unresolved risks.

## Subagent Utilization Floor

The utilization floor applies only after Socratic clarification is satisfied, average ambiguity is `<= 8%`, and runtime delegation permission is present.

When subagent tooling is available and allowed:

- For complex or multi-step work, spawn at least one read-only specialist subagent before implementation unless fallback or an explicit skip condition applies.
- Spawn at least one pre-implementation specialist subagent before editing files when the task is non-trivial and delegation permission is present.
- For multi-area work, prefer `feature-slicer` before planner or worker handoff.
- Spawn feature-scoped specialists when a slice needs domain planning: `service-template`, `frontend-ui`, `tdd-test`, `reference-auditor`, or `docs-harness-specialist`.
- For implementation tasks that create a meaningful diff, spawn at least one post-implementation subagent: a feature-slice scoped reviewer, `code-reviewer`, `verification-runner`, or `reference-auditor`.
- Prefer perspective reviewers over one broad reviewer when the diff contains multiple feature slices: `backend-reviewer`, `frontend-reviewer`, `test-reviewer`, or `docs-harness-reviewer`.
- For backend non-trivial work, spawn `service-template` and `tdd-test` as read-only specialists before implementation unless fallback, explicit opt-out, no explicit authorization under explicit-auth runtime policy, or a concrete skip condition applies.
- Spawn independent read-only specialists in parallel when their questions are distinct and their outputs do not block each other.
- Spawn parallel implementation workers only when write sets are disjoint, contracts are settled, validation can run independently, and no migration/package/solution/runtime state is shared.
- Only an actual delegated subagent task counts.
- Limit pre-implementation read-only subagents to three unless the user explicitly approves more.
- `feature-slicer` counts as coordination, not a domain specialist; still keep specialist fan-out small.
- Delegate implementation only when write sets are disjoint and requirements are settled.
- Keep review bounded: one reviewer should inspect one feature slice or one explicit perspective, not the entire diff, unless the whole change is one slice.

If an eligible role is not spawned, output `Delegation: skipped` with the concrete reason.

Report utilization floor satisfied or not.
