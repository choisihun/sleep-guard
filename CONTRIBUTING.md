# Contributing

Thanks for helping improve Sleep Guard. This project touches power management, app termination, and local system logs, so safety and test coverage matter more than speed.

## Before Opening A Pull Request

- Keep changes scoped to the owning layer in `SleepGuard/SleepGuard/`.
- Preserve graceful-only app termination as the default behavior.
- Do not broaden force termination for browsers, IDEs, development tools, or document editors without explicit maintainer discussion.
- Do not persist full `pmset -g log` output. Use bounded excerpts, session-window filtering, or streaming readers.
- Avoid direct `Process` usage for `pmset`; use the command runner abstractions.

## Development

Build:

```sh
xcodebuild -project SleepGuard/SleepGuard.xcodeproj -scheme SleepGuard -destination 'platform=macOS' build
```

Test:

```sh
xcodebuild -project SleepGuard/SleepGuard.xcodeproj -scheme SleepGuard -destination 'platform=macOS' test
git diff --check
```

## Test Expectations

Add focused tests when changing:

- command execution or pipe draining,
- `pmset` parsing or log collection,
- sleep/wake lifecycle state,
- app termination or restore policy,
- settings side effects,
- SwiftData store create/update/fetch behavior,
- report generation, scoring, diagnostics, or recommendations.

## Reporting Issues

Please include:

- macOS version and Mac model,
- whether the issue happened on battery or AC power,
- a bounded relevant log excerpt if available,
- expected behavior and actual behavior,
- steps to reproduce.

Do not paste full `pmset -g log` output if it contains unrelated activity or private app/process names.
