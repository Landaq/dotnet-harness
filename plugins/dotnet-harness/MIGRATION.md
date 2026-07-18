# Migrating to 0.5.0

## Compatibility

Existing PowerShell install, upgrade, and validation commands remain supported.
macOS should use the corresponding zsh entrypoints. Both platform entrypoints
delegate to shared Python cores so their behavior stays aligned.

Runtime agent discovery is unchanged: agents remain in `.codex/agents/*.toml`
and are invoked by their TOML `name`. The `.codex/agent-categories` tree is a
static catalog only.

Plugin skills remain the single source of truth. Install and upgrade do not copy
skills into a target project's `.codex/skills` directory.

## Removed Legacy Configuration

The caveman skill, prompt conventions, MCP entries, optional install flag, and
upgrade helper are removed. Existing repo-local caveman copies are preserved in
the upgrade backup before stale `.codex/skills` are removed from active discovery.

## Agent Policy

Agent model and reasoning profiles are now explicit. Read-only planning, review,
and specialist roles use a read-only sandbox; implementation, git, and verification
roles retain workspace write access where their commands require it.

Delegation remains conditional on the active host/runtime. A parent session may
further restrict a child agent, and hosts that require explicit authorization must
receive it before agents are spawned.

## Scaffold Changes

`ProjectName` and `ServiceName` are validated before any files are written. Names
with traversal segments, path separators, control characters, quotes, or invalid
C# identifier syntax are rejected.

`ServiceName` is supported during the initial scaffold only. Adding a service to
an existing no-service scaffold is rejected before writes because the generator's
no-overwrite contract cannot safely merge solution, AppHost, and Gateway files.

The baseline now includes a real Blazor Interactive Auto component, client assembly
routing, and the required MudBlazor providers and local static assets.

## Upgrade Procedure

Preview first, then apply with the native OS wrapper:

```powershell
pwsh -NoProfile -File assets\harness\.codex\scripts\upgrade-harness.ps1 -TargetRoot "C:\path\to\project"
pwsh -NoProfile -File assets\harness\.codex\scripts\upgrade-harness.ps1 -TargetRoot "C:\path\to\project" -Apply
```

```zsh
./assets/harness/.codex/scripts/upgrade-harness.zsh --target-root "/path/to/project"
./assets/harness/.codex/scripts/upgrade-harness.zsh --target-root "/path/to/project" --apply
```

Every apply receives a unique backup directory. If copying or post-apply
validation fails, the upgrader restores the pre-upgrade managed paths and keeps
the backup for diagnosis. An exclusive `.codex/.harness-upgrade.lock` prevents
concurrent applies, and each backup records `applying`, `complete`, `rolled-back`,
or `rollback-failed` in `transaction-state.json`. An unresolved lock or state must
be inspected before retrying an interrupted upgrade.

After migration, run the installed harness validator and the generated solution's
restore, build, and test commands.

For a release, install the pinned Playwright dependency and Chromium, then run
`Full`. Full validation starts the generated Blazor app twice: the second browser
load blocks `/_blazor` requests and must still pass the interactive counter test
through WebAssembly. GitHub Actions repeats this contract on native Windows and
macOS runners.
