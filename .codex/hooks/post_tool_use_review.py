#!/usr/bin/env python3
"""PostToolUse review hook for common .NET command failures."""

from __future__ import annotations

import json
import re
import sys
from typing import Any

FAILURE_HINTS = [
    (r"Build FAILED", "dotnet build failed. Summarize compiler errors and affected projects."),
    (r"Test Run Failed|Failed!", "dotnet test failed. Report failing tests and reproduction command."),
    (r"NU1101|NU1102|NU1605", "NuGet restore issue detected. Check package source, version, or downgrade conflict."),
    (r"CS\d{4}", "C# compiler diagnostics detected. Group them by file and error code."),
    (r"MSB\d{4}", "MSBuild diagnostics detected. Check project references and SDK version."),
    (r"The Entity Framework tools version", "EF Core tool/runtime version mismatch detected."),
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

    text = flatten(payload)
    for pattern, message in FAILURE_HINTS:
        if re.search(pattern, text, flags=re.IGNORECASE):
            print(f"[codex-review] {message}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

