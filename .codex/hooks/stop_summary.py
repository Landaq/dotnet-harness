#!/usr/bin/env python3
"""Stop hook that reminds Codex to provide a concise verification summary."""

from __future__ import annotations

import sys

MESSAGE = """
[codex-stop-check]
최종 응답에는 다음 항목을 포함하십시오.
1. 변경 파일 요약
2. 실행한 검증 명령과 결과
3. 실행하지 못한 검증과 이유
4. 보안/마이그레이션/배포 관련 남은 위험
""".strip()

print(MESSAGE, file=sys.stderr)
raise SystemExit(0)

