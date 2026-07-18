#!/usr/bin/env python3
"""Validate the repo-local dotnet-harness task-agent installation."""

from __future__ import annotations

import argparse
from html.parser import HTMLParser
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit

if sys.version_info < (3, 11):
    raise SystemExit("validate_task_agents.py requires Python 3.11 or later.")

import tomllib


REQUIRED_AGENTS = (
    "01-workflow-guardrails.toml",
    "02-goal-boundary.toml",
    "03-service-template.toml",
    "04-frontend-ui.toml",
    "05-tdd-test.toml",
    "06-reference-auditor.toml",
    "07-intake-planner.toml",
    "08-implementation-coordinator.toml",
    "09-code-reviewer.toml",
    "10-verification-runner.toml",
    "11-git-operator.toml",
    "12-backend-worker.toml",
    "13-frontend-worker.toml",
    "14-test-worker.toml",
    "15-docs-harness-worker.toml",
    "16-backend-reviewer.toml",
    "17-frontend-reviewer.toml",
    "18-test-reviewer.toml",
    "19-docs-harness-reviewer.toml",
    "20-feature-slicer.toml",
    "21-docs-harness-specialist.toml",
)

REQUIRED_KEYS = (
    "name",
    "description",
    "developer_instructions",
    "model",
    "model_reasoning_effort",
    "sandbox_mode",
)

AGENT_MODEL_ASSIGNMENTS = {
    "01-workflow-guardrails.toml": ("workflow-guardrails", "gpt-5.6-sol", "high"),
    "02-goal-boundary.toml": ("goal-boundary", "gpt-5.6-sol", "low"),
    "03-service-template.toml": ("service-template", "gpt-5.6-sol", "high"),
    "04-frontend-ui.toml": ("frontend-ui", "gpt-5.6-sol", "high"),
    "05-tdd-test.toml": ("tdd-test", "gpt-5.6-sol", "high"),
    "06-reference-auditor.toml": ("reference-auditor", "gpt-5.6-luna", "high"),
    "07-intake-planner.toml": ("intake-planner", "gpt-5.6-sol", "low"),
    "08-implementation-coordinator.toml": (
        "implementation-coordinator",
        "gpt-5.6-sol",
        "high",
    ),
    "09-code-reviewer.toml": ("code-reviewer", "gpt-5.6-sol", "high"),
    "10-verification-runner.toml": ("verification-runner", "gpt-5.6-sol", "low"),
    "11-git-operator.toml": ("git-operator", "gpt-5.6-luna", "low"),
    "12-backend-worker.toml": ("backend-worker", "gpt-5.6-terra", "high"),
    "13-frontend-worker.toml": ("frontend-worker", "gpt-5.6-terra", "high"),
    "14-test-worker.toml": ("test-worker", "gpt-5.6-terra", "high"),
    "15-docs-harness-worker.toml": (
        "docs-harness-worker",
        "gpt-5.6-terra",
        "low",
    ),
    "16-backend-reviewer.toml": ("backend-reviewer", "gpt-5.6-sol", "high"),
    "17-frontend-reviewer.toml": ("frontend-reviewer", "gpt-5.6-sol", "high"),
    "18-test-reviewer.toml": ("test-reviewer", "gpt-5.6-sol", "high"),
    "19-docs-harness-reviewer.toml": (
        "docs-harness-reviewer",
        "gpt-5.6-sol",
        "high",
    ),
    "20-feature-slicer.toml": ("feature-slicer", "gpt-5.6-sol", "high"),
    "21-docs-harness-specialist.toml": (
        "docs-harness-specialist",
        "gpt-5.6-luna",
        "high",
    ),
}

CATALOG_PAGES = {
    "index.html": None,
    "luna/index.html": "gpt-5.6-luna",
    "sol/index.html": "gpt-5.6-sol",
    "terra/index.html": "gpt-5.6-terra",
}


class AgentCatalogParser(HTMLParser):
    VOID_ELEMENTS = {
        "area",
        "base",
        "br",
        "col",
        "embed",
        "hr",
        "img",
        "input",
        "link",
        "meta",
        "param",
        "source",
        "track",
        "wbr",
    }

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.records: list[dict[str, str | list[str]]] = []
        self.counts: list[dict[str, str | list[str] | None]] = []
        self.hrefs: list[str] = []
        self._contexts: list[
            tuple[str, int | None, str | None, int | None, str | None]
        ] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = dict(attrs)
        href = values.get("href")
        if href is not None:
            self.hrefs.append(href)

        current = self._contexts[-1] if self._contexts else ("", None, None, None, None)
        _, record_index, visible_field, count_index, category = current
        classes = set((values.get("class") or "").split())
        for candidate in ("luna", "sol", "terra"):
            if candidate in classes:
                category = candidate
                break

        agent = values.get("data-agent")
        if agent is not None:
            record_index = len(self.records)
            self.records.append(
                {
                    "agent": agent,
                    "model": values.get("data-model", ""),
                    "effort": values.get("data-effort", ""),
                    "visible_model": [],
                    "visible_effort": [],
                }
            )

        if "agent-model" in classes:
            visible_field = "visible_model"
        elif "agent-effort" in classes:
            visible_field = "visible_effort"

        declared_count = values.get("data-catalog-count")
        if declared_count is not None:
            count_index = len(self.counts)
            self.counts.append(
                {
                    "declared": declared_count,
                    "visible": [],
                    "category": category,
                }
            )

        if tag not in self.VOID_ELEMENTS:
            self._contexts.append(
                (tag, record_index, visible_field, count_index, category)
            )

    def handle_endtag(self, tag: str) -> None:
        for index in range(len(self._contexts) - 1, -1, -1):
            if self._contexts[index][0] == tag:
                del self._contexts[index:]
                return

    def handle_data(self, data: str) -> None:
        if not self._contexts:
            return
        _, record_index, visible_field, count_index, _ = self._contexts[-1]
        if record_index is not None and visible_field is not None:
            visible = self.records[record_index][visible_field]
            assert isinstance(visible, list)
            visible.append(data)
        if count_index is not None:
            visible_count = self.counts[count_index]["visible"]
            assert isinstance(visible_count, list)
            visible_count.append(data)


def visible_catalog_value(parts: list[str], label: str) -> str:
    value = " ".join("".join(parts).split())
    return re.sub(rf"^{re.escape(label)}\s*:\s*", "", value, flags=re.IGNORECASE)

FIXED_AGENT_CONFIG = (
    "[mcp_servers.context7]",
    'command = "npx"',
    'args = ["-y", "@upstash/context7-mcp"]',
    "[mcp_servers.openaiDeveloperDocs]",
    'url = "https://developers.openai.com/mcp"',
)

GOAL_BOUNDARY_POLICY = (
    "After every user answer, restate the updated goal boundary",
    "After each answer, recalculate ambiguity for every active feature goal",
    "After each answer, verify goal alignment",
    "Before moving to any next work stage, explicitly tell the user the updated feature ambiguity %, average ambiguity %, goal alignment result, and next stage.",
    "After each answer, explicitly report the recalculated ambiguity and goal alignment to the user before handoff or any next stage.",
    "If the average remains above 8% or the answer shifts the target goal",
    "Socratic: satisfied",
    "Goal Alignment",
)

IMPLEMENTATION_COORDINATOR_POLICY = (
    "Select workflow mode first: `lightweight` for trivial/small work, `standard` for non-trivial work, and `deep` for explicit deep, release, scaffold, architecture, or high-risk work.",
    "In `lightweight`, keep phase contracts internal, ask at most one clarification question, do not call workers, and report only concise Socratic/change/verification/delegation/git/TaskResult status.",
    "In `standard`, start with Requirement Intake, Socratic Clarification, Ambiguity Recalculation, and Goal Boundary Confirmation",
    "In `deep`, expose full Socratic status, phase contracts, handoff gates, review, and verification evidence.",
    "Main thread is the coordinator/reporter for non-trivial work when task-agents is active.",
    "Subagents own staged analysis, implementation, review, and verification only after clarification passes and delegation permission is present.",
    "Direct main-thread edits are allowed only for direct answers, trivial one-file fixes, user opt-out, host-policy no-spawn fallback",
    "Task Agents must clarify before delegating. Actual subagent execution begins only after Socratic goal clarification is satisfied and runtime delegation permission is present.",
    "Delegation: skipped no-explicit-agent-request",
    "Each subagent output must be treated as the input contract for the next stage.",
    "Phase 0 Workflow Guardrails",
    "Phase 1 Goal Boundary",
    "Phase 2 Intake Planning",
    "Phase 3 Implementation Coordination",
    "Phase 4 Specialist Analysis",
    "Phase 5 Bounded Implementation",
    "Phase 6 Review",
    "Phase 7 Verification",
    "Phase 8 Git Operation",
    "For every phase, state `Phase`, `Agent`, `Purpose`, `Input Contract`, `Output Contract`, `Handoff Gate`, and `Next Phase`.",
    "Do not start a next phase until the current phase handoff gate passes.",
    "Worker agents are `standard`/`deep` only; never assign `backend-worker`, `frontend-worker`, `test-worker`, or `docs-harness-worker` in `lightweight`.",
    "Preferred workers are `backend-worker`, `frontend-worker`, `test-worker`, and `docs-harness-worker`.",
    "Route non-trivial multi-area work through `feature-slicer`",
    "Use feature-scoped read-only specialists",
    "Preferred feature-scoped specialists are `service-template`, `frontend-ui`, `tdd-test`, `reference-auditor`, and `docs-harness-specialist`.",
    "Route post-implementation checks to the smallest relevant reviewer set",
    "Split review work by feature slice.",
    "Prefer parallel read-only review when reviewers inspect disjoint feature slices or distinct perspectives over the same completed slice.",
    "Run workers in parallel only when write sets are disjoint, public contracts are stable, migrations are absent, package/solution files are not shared, and validation can run independently.",
    "Run workers serially when slices share files, contracts, migrations, package files, solution files, runtime state, release state, or unresolved decisions.",
    "Parallel: yes",
    "Parallel: no",
    "worker assignments",
    "feature-slicer output",
    "specialist assignments",
    "reviewer assignments by feature slice",
    "Do not hand off to the next agent until previous agent output is explicit, bounded, and usable as the next input contract.",
    "Accept previous agent output only when it includes role, scope, `Findings`, `Changes`, `Risks`, `Verify`, `Next`, affected paths, and open questions or `none`.",
    "Prior result accepted:",
    "explicit phases",
    "phase agents",
    "phase purposes",
    "input/output contracts",
    "handoff gates",
    "Require actual subagent tool calls such as `spawn_agent`",
    "main-thread role-play does not count",
    "Require `Delegation: used` evidence",
    "tool-call receipt",
    "For non-trivial work, stop before implementation",
    "Do not report `Agent execution fallback: unavailable` while `spawn_agent`",
    "Reject plans that only read TOML files",
    "A delegation plan is not delegation evidence.",
    "Delegation: skipped coupled",
    "While subagents are running, do not duplicate their implementation scope in the main thread.",
    "Delegation: skipped user-opt-out",
    "prior output contracts",
    "delegation evidence",
    "For `standard` and `deep`, report ambiguity before/after Socratic clarification, average ambiguity, goal alignment, and next stage before handoff.",
)

INTAKE_PLANNER_POLICY = (
    "@dotnet-harness",
    "$dotnet-harness",
    "dotnet-harness",
    "/feedback",
    "에이전트들이 전반적으로 수행",
    "에이전트 쓰지마",
    "clarification-first",
    "Delegation Permission: not explicit",
    "For backend non-trivial work, route pre-implementation analysis to `service-template` and `tdd-test`.",
    "Delegation: skipped user-opt-out",
)

STRUCTURED_RETURN_AGENTS = (
    "03-service-template.toml",
    "04-frontend-ui.toml",
    "05-tdd-test.toml",
    "06-reference-auditor.toml",
    "08-implementation-coordinator.toml",
    "09-code-reviewer.toml",
    "10-verification-runner.toml",
    "12-backend-worker.toml",
    "13-frontend-worker.toml",
    "14-test-worker.toml",
    "15-docs-harness-worker.toml",
    "16-backend-reviewer.toml",
    "17-frontend-reviewer.toml",
    "18-test-reviewer.toml",
    "19-docs-harness-reviewer.toml",
    "20-feature-slicer.toml",
    "21-docs-harness-specialist.toml",
)

WORKER_AGENTS = (
    "12-backend-worker.toml",
    "13-frontend-worker.toml",
    "14-test-worker.toml",
    "15-docs-harness-worker.toml",
)

REVIEWER_AGENTS = {
    "16-backend-reviewer.toml": "backend feature-slice reviewer",
    "17-frontend-reviewer.toml": "frontend feature-slice reviewer",
    "18-test-reviewer.toml": "test and validation feature-slice reviewer",
    "19-docs-harness-reviewer.toml": "docs and harness feature-slice reviewer",
}

FEATURE_SCOPED_SPECIALISTS = (
    "03-service-template.toml",
    "04-frontend-ui.toml",
    "05-tdd-test.toml",
    "06-reference-auditor.toml",
    "21-docs-harness-specialist.toml",
)


class Validator:
    def __init__(self, repo_root: Path) -> None:
        self.repo_root = repo_root
        self.catalog_dir = repo_root / ".codex" / "agent-categories"
        self.agents_dir = repo_root / ".codex" / "agents"
        self.skills_dir = repo_root / ".codex" / "skills"
        self.root_agents = repo_root / "AGENTS.md"
        self.harness_config = repo_root / ".codex" / "harness-config.json"
        self.write_task_result_script = (
            repo_root / ".codex" / "scripts" / "write-task-result.ps1"
        )
        self.write_task_result_python = (
            repo_root / ".codex" / "scripts" / "write_task_result.py"
        )
        self.platform_support = tuple(
            repo_root / ".codex" / "scripts" / name
            for name in (
                "python-env.ps1",
                "python-env.zsh",
                "upgrade-harness.ps1",
                "upgrade-harness.zsh",
                "upgrade_harness.py",
                "validate-task-agents.ps1",
                "validate-task-agents.zsh",
                "validate_task_agents.py",
            )
        )
        self.failures: list[str] = []

    def fail(self, message: str) -> None:
        self.failures.append(message)

    def require_path(self, path: Path) -> None:
        if not path.exists():
            self.fail(f"Missing path: {path}")

    @staticmethod
    def read_text(path: Path) -> str:
        return path.read_text(encoding="utf-8", errors="replace")

    @staticmethod
    def policy_pattern(text: str) -> re.Pattern[str]:
        tokens: list[str] = []
        current: list[str] = []
        token_punctuation = set("_@/$%+.-")

        for character in text:
            if character.isalnum() or character in token_punctuation:
                current.append(character)
            elif current:
                tokens.append("".join(current))
                current = []
        if current:
            tokens.append("".join(current))

        if not tokens:
            return re.compile(re.escape(text), re.IGNORECASE | re.DOTALL)

        expression = r"[\s\S]{0,120}".join(re.escape(token) for token in tokens)
        return re.compile(expression, re.IGNORECASE | re.DOTALL)

    def require_policy(
        self, content: str, required_texts: tuple[str, ...], failure_prefix: str
    ) -> None:
        for required_text in required_texts:
            if not self.policy_pattern(required_text).search(content):
                self.fail(f"{failure_prefix}: {required_text}")

    def validate_paths(self) -> None:
        for path in (
            self.catalog_dir,
            self.agents_dir,
            self.root_agents,
            self.harness_config,
            self.write_task_result_script,
            self.write_task_result_python,
            *self.platform_support,
        ):
            self.require_path(path)

        if self.skills_dir.exists():
            self.fail(
                "Repo-local .codex/skills should not exist. "
                f"Use dotnet-harness:* plugin skills instead: {self.skills_dir}"
            )

        for agent_name in REQUIRED_AGENTS:
            self.require_path(self.agents_dir / agent_name)

        for relative in CATALOG_PAGES:
            self.require_path(self.catalog_dir / relative)

    def validate_agent_files(self) -> None:
        if not self.agents_dir.exists():
            return

        agent_names: dict[str, str] = {}
        agent_files = sorted(
            path for path in self.agents_dir.glob("*.toml") if path.is_file()
        )
        actual_files = {path.name for path in agent_files}
        expected_files = set(AGENT_MODEL_ASSIGNMENTS)
        for unexpected in sorted(actual_files - expected_files):
            self.fail(f"Unexpected active agent TOML: {unexpected}")

        for agent_file in agent_files:
            try:
                with agent_file.open("rb") as handle:
                    data = tomllib.load(handle)
            except (OSError, tomllib.TOMLDecodeError) as error:
                self.fail(f"{agent_file.name} failed Python tomllib parse: {error}")
                data = {}

            missing = sorted(set(REQUIRED_KEYS) - data.keys())
            if missing:
                self.fail(f"{agent_file.name} missing keys: {', '.join(missing)}")

            for key in REQUIRED_KEYS:
                if key not in data:
                    continue
                value = data[key]
                if not isinstance(value, str) or not value.strip():
                    self.fail(f"{agent_file.name} invalid non-empty string key: {key}")

            content = self.read_text(agent_file)
            if re.search(r"^\s*\[policy\]\s*$", content, re.MULTILINE):
                self.fail(
                    f"{agent_file.name} contains unsupported [policy] table. "
                    "Keep policy as developer_instructions text."
                )

            for key in REQUIRED_KEYS:
                if not re.search(rf"^{re.escape(key)}\s*=\s*.+", content, re.MULTILINE):
                    self.fail(f"{agent_file.name} missing key: {key}")

            for key in (
                "name",
                "description",
                "model",
                "model_reasoning_effort",
                "sandbox_mode",
            ):
                match = re.search(
                    rf'^{re.escape(key)}\s*=\s*"([^"]+)"\s*$',
                    content,
                    re.MULTILINE,
                )
                if not match:
                    self.fail(f"{agent_file.name} invalid scalar string key: {key}")
                elif key == "name":
                    agent_name = match.group(1)
                    if agent_name in agent_names:
                        self.fail(
                            f"Duplicate active agent name '{agent_name}': "
                            f"{agent_names[agent_name]} and {agent_file.name}"
                        )
                    else:
                        agent_names[agent_name] = agent_file.name

            assignment = AGENT_MODEL_ASSIGNMENTS.get(agent_file.name)
            if assignment is not None:
                expected_name, expected_model, expected_effort = assignment
                for key, expected in (
                    ("name", expected_name),
                    ("model", expected_model),
                    ("model_reasoning_effort", expected_effort),
                ):
                    actual = data.get(key)
                    if actual != expected:
                        self.fail(
                            f"{agent_file.name} {key} must be {expected!r}; "
                            f"found {actual!r}"
                        )

            if not re.search(
                r'^developer_instructions\s*=\s*""".+?"""',
                content,
                re.MULTILINE | re.DOTALL,
            ):
                self.fail(
                    f"{agent_file.name} invalid developer_instructions multiline block"
                )

            if content.count('"""') % 2:
                self.fail(f"{agent_file.name} unbalanced triple quotes")

            for required_config in FIXED_AGENT_CONFIG:
                if required_config not in content:
                    self.fail(
                        f"{agent_file.name} missing fixed agent config: {required_config}"
                    )

    def validate_agent_catalog(self) -> None:
        if not self.catalog_dir.exists():
            return

        all_assignments = {
            name: (model, effort)
            for name, model, effort in AGENT_MODEL_ASSIGNMENTS.values()
        }
        category_models = {
            "luna": "gpt-5.6-luna",
            "sol": "gpt-5.6-sol",
            "terra": "gpt-5.6-terra",
        }
        repo_root = self.repo_root.resolve()

        for relative, page_model in CATALOG_PAGES.items():
            page = self.catalog_dir / relative
            if not page.is_file():
                continue

            parser = AgentCatalogParser()
            parser.feed(self.read_text(page))
            parser.close()

            records: dict[str, tuple[str, str]] = {}
            visible_records: dict[str, tuple[str, str]] = {}
            for record in parser.records:
                agent = str(record["agent"])
                model = str(record["model"])
                effort = str(record["effort"])
                if agent in records:
                    self.fail(f"Duplicate catalog agent in {relative}: {agent}")
                    continue
                records[agent] = (model, effort)
                visible_model_parts = record["visible_model"]
                visible_effort_parts = record["visible_effort"]
                assert isinstance(visible_model_parts, list)
                assert isinstance(visible_effort_parts, list)
                visible_records[agent] = (
                    visible_catalog_value(visible_model_parts, "Model"),
                    visible_catalog_value(visible_effort_parts, "Effort"),
                )

            expected = {
                agent: assignment
                for agent, assignment in all_assignments.items()
                if page_model is None or assignment[0] == page_model
            }
            if records != expected:
                missing = sorted(expected.keys() - records.keys())
                unexpected = sorted(records.keys() - expected.keys())
                mismatched = sorted(
                    agent
                    for agent in expected.keys() & records.keys()
                    if expected[agent] != records[agent]
                )
                details: list[str] = []
                if missing:
                    details.append(f"missing={','.join(missing)}")
                if unexpected:
                    details.append(f"unexpected={','.join(unexpected)}")
                if mismatched:
                    details.append(f"wrong-model-or-effort={','.join(mismatched)}")
                self.fail(
                    f"Catalog mapping mismatch in {relative}: "
                    + ("; ".join(details) if details else "unknown difference")
                )

            for agent in sorted(expected.keys() & visible_records.keys()):
                if visible_records[agent] != expected[agent]:
                    self.fail(
                        f"Visible catalog model/effort mismatch in {relative} for "
                        f"{agent}: expected {expected[agent]!r}; "
                        f"found {visible_records[agent]!r}"
                    )

            observed_count_contexts: set[str] = set()
            for count in parser.counts:
                category_value = count["category"]
                category = str(category_value) if category_value is not None else None
                context = category or "all"
                if context in observed_count_contexts:
                    self.fail(f"Duplicate catalog count in {relative}: {context}")
                    continue
                observed_count_contexts.add(context)

                if page_model is not None:
                    expected_count = len(expected)
                elif category in category_models:
                    expected_count = sum(
                        model == category_models[category]
                        for model, _ in all_assignments.values()
                    )
                else:
                    expected_count = len(expected)

                declared = str(count["declared"])
                if not declared.isdecimal() or int(declared) != expected_count:
                    self.fail(
                        f"Catalog declared count mismatch in {relative} for {context}: "
                        f"expected {expected_count}; found {declared!r}"
                    )

                visible_parts = count["visible"]
                assert isinstance(visible_parts, list)
                visible_numbers = re.findall(r"\d+", " ".join(visible_parts))
                if visible_numbers != [str(expected_count)]:
                    self.fail(
                        f"Visible catalog count mismatch in {relative} for {context}: "
                        f"expected {expected_count}; found {visible_numbers!r}"
                    )

            if page_model is None:
                missing_counts = sorted(set(category_models) - observed_count_contexts)
                if missing_counts:
                    self.fail(
                        f"Root catalog missing model counts: {','.join(missing_counts)}"
                    )
            elif not parser.counts:
                self.fail(f"Catalog page missing declared count: {relative}")

            for href in parser.hrefs:
                parts = urlsplit(href)
                if parts.scheme or parts.netloc or not parts.path:
                    continue
                target = (page.parent / unquote(parts.path)).resolve()
                try:
                    target.relative_to(repo_root)
                except ValueError:
                    self.fail(f"Catalog link escapes harness root in {relative}: {href}")
                    continue
                if not target.exists():
                    self.fail(f"Broken local catalog link in {relative}: {href}")

    def validate_named_agent_policies(self) -> None:
        policies = (
            (
                "02-goal-boundary.toml",
                GOAL_BOUNDARY_POLICY,
                "goal-boundary missing Socratic reassessment policy",
            ),
            (
                "08-implementation-coordinator.toml",
                IMPLEMENTATION_COORDINATOR_POLICY,
                "implementation-coordinator missing agent-first policy",
            ),
            (
                "07-intake-planner.toml",
                INTAKE_PLANNER_POLICY,
                "intake-planner missing agent-first intake policy",
            ),
            (
                "09-code-reviewer.toml",
                (
                    "/feedback",
                    "participate early",
                    "review scope, success criteria, risk, and likely regression surfaces",
                    "Return `Next` as actionable next-stage input, not completion proof.",
                ),
                "code-reviewer missing feedback routing policy",
            ),
            (
                "10-verification-runner.toml",
                (
                    "agents used or skipped",
                    "whether agent results were reflected",
                    "TaskResult: not requested; not created",
                    "Report whether TaskResult was explicitly requested",
                    "Git: not requested; git-operator not used",
                    "TaskResult is created only when the user explicitly says `TaskResult`, `result report`, `HTML report`, `결과 HTML`, `작업 결과 파일`",
                    "Report whether git was explicitly requested",
                ),
                "verification-runner missing final reporting policy",
            ),
            (
                "01-workflow-guardrails.toml",
                (
                    "@dotnet-harness",
                    "Delegation Permission: not explicit",
                    "direct-main opt-out wording",
                    "safety, approval, validation, TaskResult, and git gates active",
                ),
                "workflow-guardrails missing automatic handoff policy",
            ),
            (
                "11-git-operator.toml",
                (
                    "Only operate on git state when the user explicitly asks for commit, push, PR, merge, reset, clean, branch, or worktree actions.",
                ),
                "git-operator missing explicit git request policy",
            ),
        )

        for agent_name, required_texts, failure_prefix in policies:
            agent_path = self.agents_dir / agent_name
            if agent_path.exists():
                self.require_policy(
                    self.read_text(agent_path), required_texts, failure_prefix
                )

    def validate_task_result_helpers(self) -> None:
        if self.write_task_result_script.exists():
            self.require_policy(
                self.read_text(self.write_task_result_script),
                ("ArchiveDir", "NoPrune", "--archive-dir", "--no-prune"),
                "write-task-result wrapper missing retention option",
            )

        if self.write_task_result_python.exists():
            content = self.read_text(self.write_task_result_python)
            self.require_policy(
                content,
                ("archive_dir", "no_prune", "old.replace(target)", "--no-prune"),
                "write_task_result.py missing archive-based retention policy",
            )
            if re.search(r"\.unlink\(", content):
                self.fail(
                    "write_task_result.py must not delete old TaskResult files with unlink()."
                )

    def validate_agent_groups(self) -> None:
        for agent_name in STRUCTURED_RETURN_AGENTS:
            agent_path = self.agents_dir / agent_name
            if agent_path.exists():
                self.require_policy(
                    self.read_text(agent_path),
                    (
                        "Findings",
                        "Changes",
                        "Risks",
                        "Verify",
                        "Next",
                        "Preserve exact file paths, commands, errors, API names",
                    ),
                    f"{agent_name} missing structured return policy",
                )

        for worker_name in WORKER_AGENTS:
            worker_path = self.agents_dir / worker_name
            if worker_path.exists():
                self.require_policy(
                    self.read_text(worker_path),
                    (
                        "Require workflow mode input; refuse `lightweight` and run only in `standard` or `deep`.",
                        "Require allowed paths, forbidden paths, parallel eligibility, expected changed files, validation evidence, and stop condition.",
                    ),
                    f"{worker_name} missing worker mode gate policy",
                )

        for reviewer_name, reviewer_role in REVIEWER_AGENTS.items():
            reviewer_path = self.agents_dir / reviewer_name
            if reviewer_path.exists():
                self.require_policy(
                    self.read_text(reviewer_path),
                    (
                        reviewer_role,
                        "Review only the assigned feature slice",
                        "Do not perform broad whole-repo review",
                        "Refuse unclear handoff that lacks feature slice, allowed paths, success criteria, changed files or diff scope, and validation evidence.",
                        "Keep review bounded to the assigned feature slice.",
                    ),
                    f"{reviewer_name} missing feature-slice review policy",
                )

        for specialist_name in FEATURE_SCOPED_SPECIALISTS:
            specialist_path = self.agents_dir / specialist_name
            if specialist_path.exists():
                self.require_policy(
                    self.read_text(specialist_path),
                    (
                        "assigned feature slice",
                        "Analyze only the assigned feature slice",
                        "allowed paths",
                        "success criteria",
                        "validation evidence",
                    ),
                    f"{specialist_name} missing feature-scoped specialist policy",
                )

        feature_slicer = self.agents_dir / "20-feature-slicer.toml"
        if feature_slicer.exists():
            self.require_policy(
                self.read_text(feature_slicer),
                (
                    "Split the accepted goal into feature slices",
                    "allowed paths",
                    "forbidden paths",
                    "dependency order",
                    "parallel eligibility",
                    "validation evidence",
                    "stop condition",
                ),
                "feature-slicer missing slice contract",
            )

    @staticmethod
    def files_in_scope(scope: Path) -> list[Path]:
        if not scope.exists():
            return []
        if scope.is_dir():
            return sorted(path for path in scope.rglob("*") if path.is_file())
        return [scope]

    def validate_hardcodes_and_local_skills(self) -> None:
        repo_name = self.repo_root.name
        hardcode_patterns = (
            re.compile(re.escape(str(self.repo_root))),
            re.compile(rf"Test\\{re.escape(repo_name)}"),
            re.compile("workflow-agent-orchestration"),
            re.compile(r"Rev[0-9]{2}"),
        )
        scopes = (self.agents_dir, self.root_agents)

        for scope in scopes:
            for search_file in self.files_in_scope(scope):
                for line_number, line in enumerate(
                    self.read_text(search_file).splitlines(), start=1
                ):
                    for pattern in hardcode_patterns:
                        if pattern.search(line):
                            self.fail(
                                f"Hardcode pattern '{pattern.pattern}' found: "
                                f"{search_file}:{line_number}"
                            )

        local_skill_pattern = re.compile(r"\.codex[/\\]skills")
        for scope in scopes:
            for search_file in self.files_in_scope(scope):
                for line_number, line in enumerate(
                    self.read_text(search_file).splitlines(), start=1
                ):
                    if local_skill_pattern.search(line):
                        self.fail(
                            f"Repo-local skill reference found: "
                            f"{search_file}:{line_number}"
                        )

    def validate_git_diff(self) -> None:
        try:
            git_root = subprocess.run(
                ("git", "-C", str(self.repo_root), "rev-parse", "--show-toplevel"),
                check=False,
                capture_output=True,
                text=True,
            )
        except FileNotFoundError:
            print("Skipping git diff --check: git is unavailable.")
            return

        if git_root.returncode != 0 or not git_root.stdout.strip():
            print("Skipping git diff --check: not a git repository.")
            return

        diff_check = subprocess.run(
            (
                "git",
                "-C",
                str(self.repo_root),
                "diff",
                "--check",
                "--",
                ".codex/agent-categories",
                ".codex/agents",
                "AGENTS.md",
            ),
            check=False,
            capture_output=True,
            text=True,
        )
        if diff_check.returncode != 0:
            detail = (diff_check.stdout + diff_check.stderr).strip()
            self.fail(f"git diff --check failed{': ' + detail if detail else ''}")

    def validate(self) -> int:
        self.validate_paths()
        self.validate_agent_files()
        self.validate_agent_catalog()
        self.validate_named_agent_policies()
        self.validate_task_result_helpers()
        self.validate_agent_groups()
        self.validate_hardcodes_and_local_skills()
        self.validate_git_diff()

        if self.failures:
            print("Task agents validation failed:")
            for failure in self.failures:
                print(f"- {failure}")
            return 1

        print("Task agents validation passed.")
        return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate a dotnet-harness task-agent installation."
    )
    parser.add_argument(
        "--repo-root",
        default=Path.cwd(),
        type=Path,
        help="Installed harness repository root (default: current directory).",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo_root = args.repo_root.expanduser().resolve()
    return Validator(repo_root).validate()


if __name__ == "__main__":
    raise SystemExit(main())
