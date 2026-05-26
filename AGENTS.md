# Role: Sleep Guard Project Orchestrator

> To AI: This file is the top-level ruleset for this repository. Reference it before code generation, code modification, tests, or git operations.
> Final responses to the user should be in Korean unless the user explicitly asks otherwise.

## Quick Decision Tree

```
Analyze User Request
├── macOS app lifecycle / sleep-wake behavior → App + Core/Power rules below
├── pmset / command execution / log parsing → Core/PMSet rules below
├── app termination / restore safety → Core/Apps rules below
├── SwiftData persistence / reports / snapshots → Data rules below
├── SwiftUI view / view model change → Features rules below
├── tests / build verification → Testing rules below
├── README / docs → Documentation rules below
└── git commit / staging → .rules/git_agent.md
```

Priority on conflicts: system/developer instructions > this `AGENTS.md` > `.rules/` files > local style inferred from code.

## 1. Project Snapshot

- Product: Sleep Guard, a macOS 14+ native menu bar app.
- Stack: Swift, SwiftUI, AppKit, SwiftData, XCTest, Swift Testing.
- Xcode project: `SleepGuard/SleepGuard.xcodeproj`.
- Main scheme: `SleepGuard`.
- App target path: `SleepGuard/SleepGuard/`.
- Test target path: `SleepGuard/SleepGuardTests/`.

## 2. Directory Responsibilities

```
SleepGuard/SleepGuard/
├── App/              # AppDelegate, dependency container, main controllers, window/status bar wiring.
├── Core/             # Domain services: PMSet, power events, battery, app termination/restore, analysis.
├── Data/             # SwiftData models and store protocols/implementations.
├── DesignSystem/     # Shared SwiftUI components.
├── Features/         # SwiftUI screens and view models by feature.
└── Resources/        # JSON policy/scoring configuration.
```

Keep changes inside the owning layer. Do not move code across layers unless the user asks for a refactor and tests justify it.

## 3. Core Safety Rules

- This app may terminate and restore user apps. Prefer user data safety over aggressive cleanup.
- Default termination policy must remain graceful-only. Force termination requires explicit global setting, app-level opt-in, and policy allowlist.
- Treat browsers, IDE/development tools, and document editors as high data-loss risk. Do not broaden force termination for these categories without explicit user approval.
- Restore only trusted local `.app` bundles. Do not open arbitrary URL schemes or paths outside approved Applications directories.
- `pmset -g log` output can be large. Avoid loading or storing full logs in UI or persistence. Prefer streaming, session-window filtering, bounded excerpts, or bounded tail views.
- Long-running command output must be drained while the process runs. Do not reintroduce post-exit-only pipe reads.
- Sleep/wake/screen sleep events must be serialized through lifecycle state. Avoid parallel `Task` entrypoints that mutate session/report state concurrently.

## 4. Swift Style

- Follow existing Swift style in the touched file.
- Use `async/await` and `@MainActor` consistently with current store/controller protocols.
- Keep comments sparse. Add comments only to explain non-obvious safety reasoning.
- Prefer value types for stateless services and protocols for test seams.
- Keep UI strings consistent with the existing Korean app copy.
- Do not introduce third-party dependencies unless explicitly requested.

## 5. Persistence Rules

- SwiftData access belongs behind store protocols in `Data/Stores/`.
- Controller code should depend on protocols, not concrete SwiftData stores.
- When SwiftData in-memory tests are unstable, use protocol-level in-memory fakes to cover create/update/fetch flows.
- Any new report/session field needs store persistence, UI display if user-facing, and tests for migration-sensitive behavior where practical.

## 6. PMSet and Command Rules

- Use `PMSetCommandRunning` for pmset calls; avoid direct `Process` calls outside the command runner layer.
- Keep `CommandRunning.run(...)->String` usable for small bounded commands, but large-output commands should use streaming or output limits.
- Parser changes require focused tests in `SleepGuardTests/PMSet*Tests.swift`.
- Preserve diagnostics when log analysis fails. A report should distinguish "no events" from "log unavailable/unmatched".

## 7. Feature/UI Rules

- SwiftUI feature code lives under `Features/{Feature}/`.
- View models are `@MainActor ObservableObject` unless the surrounding feature uses another pattern.
- Avoid decorative UI churn. Changes should support the app workflow: dashboard, reports, logs, managed apps, settings.
- Safety-affecting toggles should communicate consequences in UI before persisting risky opt-ins.

## 8. Testing and Verification

Run the smallest useful test first while iterating, then run the full suite before finalizing behavior changes:

```sh
xcodebuild -project SleepGuard/SleepGuard.xcodeproj -scheme SleepGuard -destination 'platform=macOS' test
```

Also run:

```sh
git diff --check
```

Add or update tests when touching:
- command execution or pipe handling,
- pmset parsing/collection,
- sleep lifecycle state,
- app termination/restore policy,
- settings side effects,
- store create/update/fetch behavior,
- report generation or diagnostics.

## 9. Documentation

Keep `README.md` accurate for:
- purpose,
- permissions/system access,
- app termination policy,
- force termination risk,
- build/test commands,
- privacy and log storage scope.

## 10. Git Hygiene

- Inspect `git status --short` before staging or committing.
- Do not stage unrelated user changes.
- Never run destructive commands such as `git reset --hard`, `git clean`, or broad checkout/restore commands unless explicitly requested.
- For commit-specific rules, use `.rules/git_agent.md`.
