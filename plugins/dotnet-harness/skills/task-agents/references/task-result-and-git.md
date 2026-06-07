# TaskResult And Git

## Optional Task Result Artifact

TaskResult remains opt-in only.

TaskResult is opt-in only. Create it only when the user explicitly says `TaskResult`, `result report`, `HTML report`, `결과 HTML`, `작업 결과 파일`, or equivalent artifact request.

Create a visible HTML result file only when the user explicitly asks for a Task Result report or a result artifact:

- Directory: `docs/TaskResult` (create if missing).
- Filename: `{yyMMdd}_{summary}_Result.html`.
- Sections must be:
  1. `요청사항`
  2. `작업내용`
  3. `작업결과`
  4. `Todo`

Prefer the helper script when available:

```powershell
pwsh -NoProfile -File .codex\scripts\write-task-result.ps1 -Summary "short-summary" -Request "..." -Work "..." -Result "..." -Todo "..."
```

Before final response, do not write the Task Result unless explicitly requested.

## Git

Only use discovered `git-operator` when the user explicitly asks for commit, push, PR, branch, merge, reset, clean, or worktree actions.

Git`: `not requested; git-operator not used

TaskResult`: `not requested; not created
