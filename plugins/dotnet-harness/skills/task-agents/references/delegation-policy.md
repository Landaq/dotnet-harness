# Delegation Policy

## Agent Execution Contract

Task Agents must use actual subagents when subagent tooling is available and the task is non-trivial.

- Actual subagent execution means calling an available delegated-agent tool such as `spawn_agent` or the environment's equivalent subagent runner.
- Before fallback, inspect active callable tools.
- Do not report `Agent execution fallback: unavailable` while such a tool is callable.
- Do not report `Agent execution fallback: unavailable` while `spawn_agent`, `delegate_task`, `run_agent`, or an equivalent delegated-agent tool is callable.
- Reading agent TOML, summarizing an agent persona, or role-playing a specialist in the main thread does not count as subagent execution.
- Use `dotnet-harness:*` plugin skills as the skill contract inside the delegated prompt.
- Keep the main thread responsible for scope, approvals, final integration, file ownership, and final answer.
- Do not spawn subagents for trivial one-file edits, direct user questions, or work whose next step is fully blocked on one local decision.
- For non-trivial work, proceeding with main-thread-only execution while subagent tooling is available is noncompliant unless the decision is reported as `Delegation: skipped` with `trivial`, `blocked`, `coupled`, or `unsafe`.
- For non-trivial work, stop before implementation until either a delegated-agent tool-call receipt exists or fallback is proven by tool availability check.
- Reject plans that only read TOML files, summarize personas, or simulate specialist reasoning in the main thread.
- A delegation plan is not delegation evidence.

Delegated prompt must include:

1. selected role name;
2. active goal and non-goals;
3. allowed paths and forbidden paths;
4. expected output or changed file list;
5. validation command or evidence requirement;
6. instruction to avoid git operations unless the role is `git-operator` and the user explicitly requested git work.

## Delegation Evidence

When subagent tooling is available and used, Task Agents output must include `Delegation: used` before or during implementation:

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

`Delegation: used` is valid only when backed by an actual tool-call receipt visible in the transcript. Do not synthesize this block from a delegation plan.

Do not mark utilization satisfied from planned delegation, simulated agent reasoning, or reading `.codex/agents/*.toml`.

No-spawn decisions must include the exact reason.

## Compressed Agent Handoff

Use `caveman full` only for internal subagent handoff prompts and subagent return summaries.

Do not use `caveman full` for user-facing Socratic questions.

Compressed handoffs must preserve exact file paths, commands, errors, API names, package names, versions, agent names, skill names, and line references.

Internal handoff prompt format:

```text
Mode: caveman full
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

For non-trivial Task Agents work, the default is delegation, not local-only execution.

When subagent tooling is available:

- For complex or multi-step work, spawn at least one read-only specialist subagent before implementation unless fallback or an explicit skip condition applies.
- Spawn at least one pre-implementation specialist subagent before editing files, unless the task is a direct answer, status check, trivial one-file mechanical edit, or fully blocked on a user decision.
- For implementation tasks that create a meaningful diff, spawn at least one post-implementation subagent: `code-reviewer`, `verification-runner`, or `reference-auditor`.
- For backend non-trivial work, spawn `service-template` and `tdd-test` as read-only specialists before implementation unless fallback, explicit opt-out, or a concrete skip condition applies.
- Only an actual delegated subagent task counts.
- Limit pre-implementation read-only subagents to three unless the user explicitly approves more.
- Delegate implementation only when write sets are disjoint and requirements are settled.

If an eligible role is not spawned, output `Delegation: skipped` with the concrete reason.

Report utilization floor satisfied or not.
