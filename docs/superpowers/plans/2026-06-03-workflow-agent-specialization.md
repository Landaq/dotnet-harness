# Workflow Agent Specialization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add workflow-stage agents that separate request intake, implementation coordination, code review, verification, and explicit git operations.

**Architecture:** Keep the existing domain agents and `task-agents` discovery-first model. Add five workflow agents, narrow `workflow-guardrails` to safety gates, and update `task-agents` routing to support read-only parallel analysis and review while keeping implementation serial.

**Tech Stack:** Codex repo-local agent TOML files, Markdown skill instructions, PowerShell validation commands, Python `quick_validate.py` for skill validation when available.

---

## File Structure

- Modify: `.codex/agents/01-workflow-guardrails.toml`
  - Responsibility: safety and approval gate only.
- Create: `.codex/agents/06-intake-planner.toml`
  - Responsibility: request interpretation, success criteria, affected paths, outputs, and open questions.
- Create: `.codex/agents/07-implementation-coordinator.toml`
  - Responsibility: agent selection, parallel analysis decision, serial implementation order, result merge.
- Create: `.codex/agents/08-code-reviewer.toml`
  - Responsibility: post-change diff review focused on bugs, regressions, scope, tests, and boundaries.
- Create: `.codex/agents/09-verification-runner.toml`
  - Responsibility: select and interpret the smallest verification command or inspection.
- Create: `.codex/agents/10-git-operator.toml`
  - Responsibility: explicit user-approved stage, commit, push, and PR preparation.
- Modify: `.codex/skills/task-agents/SKILL.md`
  - Responsibility: document updated discovery, routing, parallel analysis, review, and stop rules.
- Inspect only: `.codex/skills/task-agents/agents/openai.yaml`
  - Responsibility: display metadata. Update only if it contradicts the new workflow-stage routing.

Do not modify application code, solution files, existing domain skills, or `project-structure-setup`.

---

### Task 1: Baseline Inspection

**Files:**
- Inspect: `.codex/agents/*.toml`
- Inspect: `.codex/skills/task-agents/SKILL.md`
- Inspect: `.codex/skills/task-agents/agents/openai.yaml`

- [ ] **Step 1: Check current working tree**

Run:

```powershell
git status --short
```

Expected: Existing unrelated dirty files may be present. Do not stage or revert them.

- [ ] **Step 2: List current agents**

Run:

```powershell
Get-ChildItem -Path ".codex\agents" -File | Select-Object -ExpandProperty Name
```

Expected output includes:

```text
01-workflow-guardrails.toml
02-service-template.toml
03-frontend-ui.toml
04-tdd-test.toml
05-reference-auditor.toml
```

- [ ] **Step 3: Capture current task-agents routing**

Run:

```powershell
rg -n "Routing Order|Agent Selection Rules|Output Contract|Stop Conditions" .codex\skills\task-agents\SKILL.md
```

Expected: Matches for the existing routing sections.

- [ ] **Step 4: Confirm no existing new workflow agents**

Run:

```powershell
Test-Path ".codex\agents\06-intake-planner.toml"
Test-Path ".codex\agents\07-implementation-coordinator.toml"
Test-Path ".codex\agents\08-code-reviewer.toml"
Test-Path ".codex\agents\09-verification-runner.toml"
Test-Path ".codex\agents\10-git-operator.toml"
```

Expected: All five commands return `False`.

---

### Task 2: Add Workflow Agent TOML Files

**Files:**
- Create: `.codex/agents/06-intake-planner.toml`
- Create: `.codex/agents/07-implementation-coordinator.toml`
- Create: `.codex/agents/08-code-reviewer.toml`
- Create: `.codex/agents/09-verification-runner.toml`
- Create: `.codex/agents/10-git-operator.toml`

- [ ] **Step 1: Create `06-intake-planner.toml`**

Write exactly:

```toml
name = "intake-planner"
description = "Translate user requests into work units, success criteria, affected paths, expected outputs, and open questions after workflow-guardrails clears safety constraints."
developer_instructions = """
You are the intake planning specialist for this repository.

Use .codex/skills/task-agents/SKILL.md as the orchestration contract. If this agent and that skill disagree, follow the skill unless the user gives a newer direct instruction.

Primary responsibilities:
- Restate the user request as concrete work units.
- Identify success criteria, expected outputs, affected paths, and likely validation commands.
- Surface assumptions and open questions in Korean when clarification is needed.
- Keep safety, destructive action, git publishing, secret handling, production access, and approval decisions delegated to workflow-guardrails.
- Hand off specialist sequencing decisions to implementation-coordinator.

Execution rules:
1. Do not implement code or edit files.
2. Do not approve destructive, git-publishing, database, credential, or production actions.
3. Ask at most three Korean clarification questions when acceptance criteria, target project, service boundary, render mode, or requested output is unclear.
4. Keep outputs concrete: work units, affected paths, success criteria, validation candidates, and next routing recommendation.
"""
model_reasoning_effort = "high"
sandbox_mode = "workspace-write"
```

- [ ] **Step 2: Create `07-implementation-coordinator.toml`**

Write exactly:

```toml
name = "implementation-coordinator"
description = "Select applicable repo-local agents and skills, decide safe read-only parallel analysis, merge specialist outputs, and define the final serial implementation order."
developer_instructions = """
You are the implementation coordination specialist for this repository.

Use .codex/skills/task-agents/SKILL.md as the orchestration contract. If this agent and that skill disagree, follow the skill unless the user gives a newer direct instruction.

Primary responsibilities:
- Choose which discovered agents or skills apply by name and description.
- Decide when read-only parallel specialist analysis is useful.
- Merge specialist constraints into one implementation order.
- Keep actual file edits serial unless the user explicitly approves a safer isolated workflow.
- Route post-implementation checks to code-reviewer, verification-runner, and reference-auditor when relevant.

Execution rules:
1. Do not edit files while collecting parallel analysis.
2. Do not run git-operator until implementation and review/verification are complete and the user explicitly requested git work.
3. Prefer the smallest specialist set that covers the work.
4. Report the final route as ordered stages, parallel groups, blocked gates, and validation commands.
"""
model_reasoning_effort = "high"
sandbox_mode = "workspace-write"
```

- [ ] **Step 3: Create `08-code-reviewer.toml`**

Write exactly:

```toml
name = "code-reviewer"
description = "Review completed diffs for bugs, regressions, excessive scope, missing tests, and architecture or boundary violations before completion."
developer_instructions = """
You are the code review specialist for this repository.

Use .codex/skills/task-agents/SKILL.md as the orchestration contract. Follow the repository code-review stance: findings first, ordered by severity, with file and line references when available.

Primary responsibilities:
- Review changed files and diffs after implementation.
- Prioritize bugs, behavioral regressions, missing tests, boundary violations, and excessive unrelated changes.
- Identify whether existing dirty-tree changes appear unrelated and should stay unstaged.
- Keep summaries brief and secondary to findings.
- Recommend concrete fixes or verification when risk remains.

Execution rules:
1. Do not edit files during review unless the user explicitly asks for fixes.
2. Do not approve completion without verification-runner evidence when behavior or routing changed.
3. Report no findings clearly when no actionable issues are found.
4. Include residual risk and test gaps after findings.
"""
model_reasoning_effort = "high"
sandbox_mode = "workspace-write"
```

- [ ] **Step 4: Create `09-verification-runner.toml`**

Write exactly:

```toml
name = "verification-runner"
description = "Select the smallest command or file inspection that proves the requested change and report actual outcomes before completion claims."
developer_instructions = """
You are the verification specialist for this repository.

Use .codex/skills/task-agents/SKILL.md as the orchestration contract. Treat verification evidence as required before claiming work is complete.

Primary responsibilities:
- Select the smallest build, test, lint, search, or file-inspection command that proves the change.
- Run or specify validation commands appropriate to the touched files.
- Interpret actual command outcomes and separate passing evidence from residual risk.
- Prefer quick_validate.py for repo-local skill validation when skill files changed.
- Confirm agent inventory and metadata when agent TOML files changed.

Execution rules:
1. Do not claim success from intent or unrun commands.
2. If a command cannot run, report the exact blocker and choose the next best local inspection.
3. Do not mutate source files.
4. Keep verification scoped to the change unless broad behavior was affected.
"""
model_reasoning_effort = "high"
sandbox_mode = "workspace-write"
```

- [ ] **Step 5: Create `10-git-operator.toml`**

Write exactly:

```toml
name = "git-operator"
description = "Handle user-approved git staging, commits, pushes, and pull-request preparation with narrow staging and dirty-tree protection."
developer_instructions = """
You are the git operation specialist for this repository.

Use .codex/skills/task-agents/SKILL.md as the orchestration contract. Only operate on git state when the user explicitly asks for commit, push, PR, merge, reset, clean, branch, or worktree actions.

Primary responsibilities:
- Inspect dirty tree state before staging.
- Stage only files tied directly to the approved task.
- Keep unrelated modified or untracked files out of commits.
- Prepare concise commit messages and report staged scope before commit.
- Handle push or PR preparation only after explicit user approval.

Execution rules:
1. Do not run destructive git commands without explicit user instruction and approval.
2. Do not stage broad paths when unrelated dirty-tree changes exist.
3. Do not push, merge, reset, clean, or create PRs unless explicitly requested.
4. Report commit SHA and remaining dirty tree after successful commit.
"""
model_reasoning_effort = "high"
sandbox_mode = "workspace-write"
```

- [ ] **Step 6: Verify new TOML files exist**

Run:

```powershell
Get-ChildItem -Path ".codex\agents" -File | Select-Object -ExpandProperty Name
```

Expected output includes ordered files:

```text
01-workflow-guardrails.toml
02-service-template.toml
03-frontend-ui.toml
04-tdd-test.toml
05-reference-auditor.toml
06-intake-planner.toml
07-implementation-coordinator.toml
08-code-reviewer.toml
09-verification-runner.toml
10-git-operator.toml
```

---

### Task 3: Narrow `workflow-guardrails`

**Files:**
- Modify: `.codex/agents/01-workflow-guardrails.toml`

- [ ] **Step 1: Update the description**

Change:

```toml
description = "Use architecture-workflow-guardrails to classify Rev06 work, reduce ambiguity, define approvals, and sequence specialist handoffs before implementation."
```

To:

```toml
description = "Use architecture-workflow-guardrails as the first safety and approval gate before intake planning, coordination, implementation, verification, or git operations."
```

- [ ] **Step 2: Replace broad planning responsibilities inside `developer_instructions`**

Inside `developer_instructions`, keep the existing header and skill reference, then make the responsibility block read:

```text
Primary responsibilities:
- Act as the first safety and approval gate for repository work.
- Classify whether the request involves destructive actions, git publishing, branch/worktree changes, merges, resets, cleans, database changes, secrets, credentials, private keys, production access, or unclear approval boundaries.
- Identify whether the request is complex, backend, frontend, audit, test-only, or git-operation work so intake-planner and implementation-coordinator can route it.
- Ask at most three numbered Korean clarification questions when safety, approval, service boundary, target project, or acceptance criteria is unclear.
- Hand off planning details to intake-planner and specialist sequencing to implementation-coordinator after safety constraints are clear.
```

Make the execution rules read:

```text
Execution rules:
1. Do not implement while required scope, service boundary, target project, approval boundary, or test strategy is unclear.
2. Do not own broad implementation planning; delegate work-unit planning to intake-planner.
3. Keep destructive actions, commits, pushes, branch changes, worktrees, merges, resets, cleans, migrations, secret handling, and database changes behind explicit approval.
4. Keep outputs concrete: workflow mode, safety gate result, ambiguity estimate, approval requirements, affected path hints, and next routing target.
5. Never print secrets, tokens, connection strings, private keys, credentials, or production account data.
```

- [ ] **Step 3: Verify workflow-guardrails no longer owns broad planning**

Run:

```powershell
rg -n "sequence specialist handoffs|implementation plan|broad implementation planning|intake-planner|implementation-coordinator" .codex\agents\01-workflow-guardrails.toml
```

Expected:

```text
.codex\agents\01-workflow-guardrails.toml:<line>:description = "Use architecture-workflow-guardrails as the first safety and approval gate before intake planning, coordination, implementation, verification, or git operations."
.codex\agents\01-workflow-guardrails.toml:<line>:- Hand off planning details to intake-planner and specialist sequencing to implementation-coordinator after safety constraints are clear.
.codex\agents\01-workflow-guardrails.toml:<line>:2. Do not own broad implementation planning; delegate work-unit planning to intake-planner.
```

---

### Task 4: Update `task-agents` Routing

**Files:**
- Modify: `.codex/skills/task-agents/SKILL.md`

- [ ] **Step 1: Replace the `## Routing Order` section**

Replace the existing `## Routing Order` section through the end of the verification stage with:

```markdown
## Routing Order

Run stages in order unless user narrows task:

1. **Safety gate**
   - Use discovered workflow/guardrails agent or skill first.
   - Identify destructive actions, git publishing, branch/worktree changes, merges, resets, cleans, database changes, secret handling, production access, and unclear approval boundaries.
   - Classify the request as complex, backend, frontend, audit, test-only, verification-only, or git-operation work.
   - If ambiguity exceeds the discovered guardrail threshold, ask max three Korean clarification questions; pause implementation.

2. **Intake planning**
   - Use discovered intake/planner agent when present.
   - Convert the request into work units, affected paths, success criteria, expected outputs, and validation candidates.
   - Keep safety approvals owned by the workflow/guardrails stage.

3. **Implementation coordination**
   - Use discovered implementation/coordinator agent when present.
   - Select applicable domain, test, audit, review, verification, and git agents by discovered `name` + `description`.
   - Decide whether read-only parallel specialist analysis is useful.
   - Merge specialist outputs into one serial implementation order.

4. **Read-only parallel specialist analysis**
   - Backend work can analyze with service-template + TDD/test in parallel.
   - UI/API work can analyze with frontend/UI + service-template + TDD/test in parallel.
   - Structure/governance work can analyze with reference/audit + TDD/test in parallel.
   - Parallel analysis must produce constraints, risks, test requirements, and recommended order; it must not edit files.

5. **Serial implementation**
   - Implement only after safety constraints, work units, specialist constraints, and test strategy are clear.
   - Backend service structure/boundary work routes through discovered service-template agent/skill.
   - Frontend/UI component work routes through discovered frontend-ui agent/skill.
   - Behavior-changing work routes through discovered TDD/test agent/skill before implementation.
   - Keep edits surgical and tied to the user request.

6. **Post-implementation review**
   - Use discovered code-reviewer when present.
   - Run relevant specialist review again for touched domains.
   - For broad/architecture changes, run reference-auditor before completion.
   - Findings come first, followed by residual risk and test gaps.

7. **Verification**
   - Use discovered verification-runner when present.
   - Run the smallest command proving the claim: build, test, lint, file inspection, metadata check, or targeted search.
   - Report actual command outcomes. Do not claim completion from intent.

8. **Explicit git operation**
   - Use discovered git-operator only when the user explicitly asks for commit, push, PR, branch, merge, reset, clean, or worktree actions.
   - Inspect dirty tree, stage narrowly, and leave unrelated changes unstaged.
```

- [ ] **Step 2: Replace the `## Agent Selection Rules` capability list**

Replace the capability bullets with:

```markdown
- workflow or guardrails: safety, approvals, ambiguity, destructive-action gates.
- intake or planner: work units, affected paths, success criteria, expected outputs.
- implementation or coordinator: specialist selection, parallel analysis decision, serial implementation order.
- service or backend template: service folders, DDD/Clean Architecture layers, contracts.
- frontend or UI policy: Blazor UI, component library choice, render mode, Web.Client safety.
- TDD or test: Red-Green-Refactor, test placement, validation scope.
- reference or audit: architecture/process comparison and prioritized remediation.
- code reviewer or review: diff risks, regressions, scope creep, missing tests, boundary violations.
- verification or runner: command selection, actual result interpretation, completion evidence.
- git operator: explicit user-approved staging, commit, push, and PR preparation.
```

- [ ] **Step 3: Add a `## Parallelization Rules` section before `## Output Contract`**

Insert:

```markdown
## Parallelization Rules

Use parallel work only when outputs are independent and read-only, or when post-implementation reviewers inspect the same completed diff without editing it.

Safe parallel groups:

- Pre-implementation backend analysis: service-template + TDD/test.
- Pre-implementation UI/API analysis: frontend/UI + service-template + TDD/test.
- Pre-implementation structure analysis: reference/audit + TDD/test.
- Post-implementation review: code-reviewer + verification-runner + reference/auditor when architecture boundaries changed.

Unsafe parallel work:

- Multiple agents editing the same files.
- git-operator running before implementation, review, and verification finish.
- Implementation before workflow/guardrails clears approval constraints.
- Multiple remediation attempts before a test failure cause is identified.
```

- [ ] **Step 4: Update `## Output Contract`**

Replace the output bullets with:

```markdown
- `Stage`: current workflow stage.
- `Discovered`: relevant agents/skills found.
- `Route`: ordered stages, including any safe parallel read-only groups.
- `Gate`: clarification, approval, test, verification, or git requirement.
- `Action`: what happens next.
```

- [ ] **Step 5: Update `## Stop Conditions`**

Ensure the stop list includes:

```markdown
- service boundary, target project, render mode, or acceptance criteria unclear;
- destructive, database, secret, production, or git-publishing action needed;
- multiple agents would need to edit the same files in parallel;
- no discovered agent/skill safely covers high-risk stage.
```

- [ ] **Step 6: Verify routing text**

Run:

```powershell
rg -n "Safety gate|Intake planning|Implementation coordination|Read-only parallel specialist analysis|Post-implementation review|Explicit git operation|Parallelization Rules|git-operator|verification-runner|code-reviewer" .codex\skills\task-agents\SKILL.md
```

Expected: Each new routing concept appears at least once.

---

### Task 5: Inspect Display Metadata

**Files:**
- Inspect: `.codex/skills/task-agents/agents/openai.yaml`
- Modify only if needed: `.codex/skills/task-agents/agents/openai.yaml`

- [ ] **Step 1: Read metadata**

Run:

```powershell
Get-Content -Path ".codex\skills\task-agents\agents\openai.yaml" | Select-Object -First 120
```

Expected: Metadata refers to `task-agents`.

- [ ] **Step 2: Decide whether metadata needs a change**

If the metadata description already broadly says the skill routes repo-local task agents and skills, make no change.

If it says only the old six-stage flow and omits workflow-stage agents, update only the description text to:

```yaml
description: Route project work through discovered repo-local task agents and skills, including workflow-stage intake, coordination, review, verification, and explicit git-operation handling.
```

- [ ] **Step 3: Verify metadata still references task-agents**

Run:

```powershell
rg -n "task-agents|intake|coordination|verification|git" .codex\skills\task-agents\agents\openai.yaml
```

Expected: `task-agents` appears. New workflow terms appear only if Step 2 changed metadata.

---

### Task 6: Validate Agent and Skill Changes

**Files:**
- Validate: `.codex/agents/*.toml`
- Validate: `.codex/skills/task-agents/SKILL.md`
- Validate: `.codex/skills/*/SKILL.md`

- [ ] **Step 1: Check agent inventory**

Run:

```powershell
Get-ChildItem -Path ".codex\agents" -File | Select-Object -ExpandProperty Name
```

Expected: Ordered files `01` through `10` are present.

- [ ] **Step 2: Check required TOML keys**

Run:

```powershell
rg -n "^(name|description|developer_instructions|model_reasoning_effort|sandbox_mode) =" .codex\agents
```

Expected: Each of the ten agent files has all five required keys.

- [ ] **Step 3: Check old workflow-only assumptions are not left in task-agents**

Run:

```powershell
rg -n "Implementation handoff|Review and audit|Run stages in order unless user narrows task" .codex\skills\task-agents\SKILL.md
```

Expected: `Run stages in order unless user narrows task` remains. Old stage names `Implementation handoff` and `Review and audit` should not appear.

- [ ] **Step 4: Run skill validation when available**

Run:

```powershell
python C:\Users\cwnv2002\.codex\skills\.system\skill-creator\scripts\quick_validate.py .codex\skills\architecture-workflow-guardrails
python C:\Users\cwnv2002\.codex\skills\.system\skill-creator\scripts\quick_validate.py .codex\skills\frontend-ui-policy
python C:\Users\cwnv2002\.codex\skills\.system\skill-creator\scripts\quick_validate.py .codex\skills\project-structure-setup
python C:\Users\cwnv2002\.codex\skills\.system\skill-creator\scripts\quick_validate.py .codex\skills\reference-comparison-audit
python C:\Users\cwnv2002\.codex\skills\.system\skill-creator\scripts\quick_validate.py .codex\skills\service-template-setup
python C:\Users\cwnv2002\.codex\skills\.system\skill-creator\scripts\quick_validate.py .codex\skills\task-agents
python C:\Users\cwnv2002\.codex\skills\.system\skill-creator\scripts\quick_validate.py .codex\skills\tdd-test-workflow
```

Expected: Each command reports validation success. If sandbox process creation fails, report the exact failure and perform Steps 1-3 plus `git diff --check` as fallback evidence.

- [ ] **Step 5: Check whitespace**

Run:

```powershell
git diff --check -- .codex\agents .codex\skills\task-agents
```

Expected: No output.

---

### Task 7: Review and Commit Only Approved Files

**Files:**
- Stage: `.codex/agents/01-workflow-guardrails.toml`
- Stage: `.codex/agents/06-intake-planner.toml`
- Stage: `.codex/agents/07-implementation-coordinator.toml`
- Stage: `.codex/agents/08-code-reviewer.toml`
- Stage: `.codex/agents/09-verification-runner.toml`
- Stage: `.codex/agents/10-git-operator.toml`
- Stage: `.codex/skills/task-agents/SKILL.md`
- Stage if modified: `.codex/skills/task-agents/agents/openai.yaml`

- [ ] **Step 1: Review diff scope**

Run:

```powershell
git diff -- .codex\agents .codex\skills\task-agents
```

Expected: Diff is limited to the approved agent and `task-agents` files.

- [ ] **Step 2: Check dirty tree before staging**

Run:

```powershell
git status --short
```

Expected: Existing unrelated dirty `.codex/skills/*` files and `architecture/` may still appear. Do not stage them.

- [ ] **Step 3: Stage narrowly**

Run:

```powershell
git add .codex/agents/01-workflow-guardrails.toml
git add .codex/agents/06-intake-planner.toml
git add .codex/agents/07-implementation-coordinator.toml
git add .codex/agents/08-code-reviewer.toml
git add .codex/agents/09-verification-runner.toml
git add .codex/agents/10-git-operator.toml
git add .codex/skills/task-agents/SKILL.md
```

If `.codex/skills/task-agents/agents/openai.yaml` changed, also run:

```powershell
git add .codex/skills/task-agents/agents/openai.yaml
```

- [ ] **Step 4: Confirm staged scope**

Run:

```powershell
git diff --cached --stat
git status --short
```

Expected: Staged files are only the approved workflow-agent files and `task-agents` files. Unrelated dirty files remain unstaged.

- [ ] **Step 5: Commit only if user explicitly requested commit**

If the user requested commit, run:

```powershell
git commit -m "feat(codex): specialize workflow agents"
```

Expected: Commit succeeds and reports the new commit SHA.

If the user did not request commit, stop after reporting the staged or unstaged implementation state.

- [ ] **Step 6: Report final state**

Run:

```powershell
git status --short
```

Expected: Any unrelated pre-existing dirty files remain visible. The implementation files are either committed or staged, depending on user instruction.

---

## Self-Review Checklist

- Spec coverage: Tasks 2-4 implement the five new workflow agents, narrowed `workflow-guardrails`, updated `task-agents` routing, and parallelization model.
- Display metadata: Task 5 handles optional `openai.yaml` changes only when needed.
- Verification: Task 6 covers agent inventory, required TOML keys, routing text, skill validation, and whitespace.
- Dirty tree safety: Task 7 stages only approved files and keeps unrelated work out.
- Scope control: No application code, solution files, domain skills, or `project-structure-setup` changes are included.
