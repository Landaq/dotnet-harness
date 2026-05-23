#!/usr/bin/env python3
"""PreToolUse safety policy for Codex Bash commands.

이 스크립트는 Codex 훅 입력 JSON을 최대한 느슨하게 파싱한 뒤 위험 명령 패턴을 감지합니다.
팀 정책에 맞춰 BLOCK_PATTERNS와 WARN_PATTERNS를 조정하십시오.
"""

from __future__ import annotations

import json
import re
import sys
from typing import Any

BLOCK_PATTERNS = [
    (r"\brm\s+-rf\s+/(\s|$)", "Refusing to remove filesystem root."),
    (r"\bgit\s+push\s+--force\b", "Force push must be performed manually after review."),
    (r"\bgit\s+reset\s+--hard\b", "Hard reset requires explicit user approval."),
    (r"\bgit\s+clean\s+-fdx\b", "Destructive clean requires explicit user approval."),
    (r"\bdotnet\s+ef\s+database\s+drop\b", "Dropping a database is forbidden from Codex automation."),
    (r"\bdotnet\s+ef\s+database\s+update\b", "Updating a database must be approved explicitly."),
    (r"\bDROP\s+DATABASE\b", "DROP DATABASE is forbidden from Codex automation."),
    (r"\bTRUNCATE\s+TABLE\b", "TRUNCATE TABLE is forbidden from Codex automation."),
    (r"\bappsettings\.Production\.json\b.*\b(cat|type|Get-Content)\b", "Do not print production settings."),
]

WARN_PATTERNS = [
    (r"\bdotnet\s+ef\s+migrations\s+add\b", "EF migration creation detected. Review generated migration carefully."),
    (r"\bUpdate-Database\b", "Database update command detected. Require explicit review."),
    (r"\bRemove-Migration\b", "Migration removal detected. Verify no shared migration is removed."),
    (r"\b(appsettings\..*\.json|\.env)\b", "Sensitive configuration file reference detected."),
]


def flatten(value: Any) -> str:
    if isinstance(value, dict):
        return " ".join(flatten(v) for v in value.values())
    if isinstance(value, list):
        return " ".join(flatten(v) for v in value)
    if value is None:
        return ""
    return str(value)


def main() -> int:
    raw = sys.stdin.read()
    try:
        payload = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        payload = {"raw": raw}

    command_text = flatten(payload)

    for pattern, message in BLOCK_PATTERNS:
        if re.search(pattern, command_text, flags=re.IGNORECASE):
            print(f"[codex-policy:block] {message}", file=sys.stderr)
            print(f"[codex-policy:block] matched pattern: {pattern}", file=sys.stderr)
            return 2

    for pattern, message in WARN_PATTERNS:
        if re.search(pattern, command_text, flags=re.IGNORECASE):
            print(f"[codex-policy:warn] {message}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

