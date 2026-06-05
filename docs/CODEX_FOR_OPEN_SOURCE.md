# Codex For Open Source Application Prep

Official program page: <https://openai.com/form/codex-for-oss/>

## What OpenAI Asks For

The official form asks for:

- public GitHub username,
- public GitHub repository URL,
- primary or core maintainer role,
- why the repository qualifies, with signals such as usage, downloads, or ecosystem importance,
- OpenAI organization ID,
- how API credits will be used,
- optional extra context.

The program page says applications are reviewed on a rolling basis and that OpenAI looks for active open-source projects with meaningful usage, broad adoption, or clear ecosystem importance. It also lists active maintenance signals such as pull request review, issue triage, release management, and other primary/core maintainer work.

## Current Readiness

- README explains the problem, feature set, screenshots, safety model, build/test flow, and privacy boundaries.
- MIT license is present.
- Contributing and security policies are present.
- GitHub description and topics are set.
- Local `v1.0.0` tag exists.
- Full macOS test suite passes locally.

## Gaps Before Submission

- Repository is still private; the form requires a public repository URL.
- GitHub profile visibility must be public.
- Local commits and tags must be pushed before the public URL reflects the current docs.
- Create a GitHub Release from the latest intended tag and attach the DMG asset instead of committing local `dist/` artifacts.
- Add measurable adoption signals once available: stars, TestFlight users, downloads, issues, contributors, or release asset downloads.
- Add a short public roadmap or issues for maintainer automation/security work if you want to show ongoing maintenance.

## Suggested Repository Description

```text
macOS menu bar app for analyzing sleep battery drain with pmset logs and safe app cleanup/restore
```

## Suggested Topics

```text
macos, swift, swiftui, appkit, swiftdata, menu-bar-app, battery, sleep, pmset, power-management
```

## Form Draft: Role

```text
Primary maintainer
```

## Form Draft: Why This Repository Qualifies

Under 500 characters:

```text
Sleep Guard tackles a common but opaque macOS problem: overnight battery drain caused by DarkWake, wake requests, assertions, and high-impact apps. It is a native Swift/SwiftUI menu bar app with bounded pmset log analysis, sleep reports, safe app cleanup/restore, tests for parsing/lifecycle policy, and clear privacy/safety boundaries.
```

## Form Draft: API Credit Use

Under 500 characters:

```text
I will use API credits for open-source maintenance: PR review, issue triage, release-note drafts, test-case generation for pmset logs, security review of app termination/restore paths, and documentation updates. Credits will support safer releases and better diagnostics without sending user sleep logs or app lists from the app.
```

## Form Draft: Anything Else

Under 500 characters:

```text
The project is designed around user-data safety: graceful termination by default, bounded pmset excerpts instead of full log storage, trusted local .app restore only, and tests covering command output draining, pmset parsing, report generation, and app termination/restore policy.
```

## Submission Checklist

1. Make GitHub profile public.
2. Make `choisihun/sleep-guard` public.
3. Push `main` and tags.
4. Create a GitHub Release with the DMG artifact.
5. Confirm README screenshots render on GitHub.
6. Fill the OpenAI form with the drafts above and your OpenAI organization ID.
