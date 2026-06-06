#!/usr/bin/env python
"""Write a task-agents HTML result artifact and prune old results."""

from __future__ import annotations

import argparse
import html
import re
from datetime import datetime
from pathlib import Path


MAX_RESULTS = 10


def slugify(value: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9_-]+", "-", value.strip().lower())
    slug = re.sub(r"-{2,}", "-", slug).strip("-_")
    return slug or "task"


def format_block(value: str) -> str:
    escaped = html.escape(value.strip() or "-")
    return escaped.replace("\n", "<br>\n")


def build_html(request: str, work: str, result: str, todo: str) -> str:
    created = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    sections = [
        ("1. 요청사항", request),
        ("2. 작업내용", work),
        ("3. 작업결과", result),
        ("4. Todo", todo),
    ]
    body = "\n".join(
        f"<section><h2>{html.escape(title)}</h2><div>{format_block(content)}</div></section>"
        for title, content in sections
    )
    return f"""<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Task Result</title>
  <style>
    :root {{
      color-scheme: light;
      --bg: #f6f7f9;
      --panel: #ffffff;
      --text: #1c2430;
      --muted: #627084;
      --line: #d8dee8;
      --accent: #176b87;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      background: var(--bg);
      color: var(--text);
      font-family: "Segoe UI", Arial, sans-serif;
      line-height: 1.55;
    }}
    main {{
      width: min(960px, calc(100% - 32px));
      margin: 32px auto;
    }}
    header {{
      border-bottom: 2px solid var(--accent);
      padding-bottom: 14px;
      margin-bottom: 18px;
    }}
    h1 {{ margin: 0 0 6px; font-size: 28px; }}
    .meta {{ color: var(--muted); font-size: 14px; }}
    section {{
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 18px 20px;
      margin: 14px 0;
    }}
    h2 {{ margin: 0 0 10px; font-size: 18px; }}
  </style>
</head>
<body>
  <main>
    <header>
      <h1>Task Result</h1>
      <div class="meta">Created: {html.escape(created)}</div>
    </header>
    {body}
  </main>
</body>
</html>
"""


def unique_path(output_dir: Path, date_prefix: str, summary: str) -> Path:
    base = f"{date_prefix}_{summary}"
    candidate = output_dir / f"{base}_Result.html"
    index = 2
    while candidate.exists():
        candidate = output_dir / f"{base}-{index}_Result.html"
        index += 1
    return candidate


def prune_results(output_dir: Path) -> None:
    results = sorted(
        output_dir.glob("*_Result.html"),
        key=lambda path: (path.stat().st_mtime, path.name),
        reverse=True,
    )
    for old in results[MAX_RESULTS:]:
        old.unlink()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Write task-agents result HTML")
    parser.add_argument("--summary", required=True)
    parser.add_argument("--request", required=True)
    parser.add_argument("--work", required=True)
    parser.add_argument("--result", required=True)
    parser.add_argument("--todo", default="")
    parser.add_argument("--output-dir", default="docs/TaskResult")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    date_prefix = datetime.now().strftime("%y%m%d")
    output_path = unique_path(output_dir, date_prefix, slugify(args.summary))
    output_path.write_text(
        build_html(args.request, args.work, args.result, args.todo),
        encoding="utf-8",
    )
    prune_results(output_dir)
    print(output_path)


if __name__ == "__main__":
    main()
