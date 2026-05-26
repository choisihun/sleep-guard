# Role: Sleep Guard Git Diff Analyst & Commit Generator

> This file applies only to git staging and commit tasks in this repository.

## Absolutely Prohibited Commands

- Do not run `git push`, `git pull`, `git reset`, `git rebase`, `git clean`, `git checkout .`, broad `git restore`, or `git merge` unless the user explicitly asks for that exact operation.
- Do not use force options.
- Do not affect remotes without explicit user confirmation.
- Do not include emoji in commit messages.

## Allowed Scope

- You may inspect status and diffs.
- You may stage only files that belong to the requested logical change.
- You may create local commits when the user asks to commit.
- Leave unrelated user changes unstaged.

## Commit Message Convention

Use Korean commit messages:

```text
<type>: <Korean summary>
```

Types:

| Type | Purpose |
|:---|:---|
| `feat` | New feature or user-visible capability |
| `fix` | Bug fix or safety correction |
| `refactor` | Internal code improvement without behavior change |
| `style` | Formatting-only change |
| `chore` | Build/config/tooling/dependency change |
| `docs` | Documentation/comment-only change |
| `test` | Test-only change |

Good summaries:

- `fix: pmset 로그 수집 메모리 사용 제한`
- `fix: wake 이벤트 중복 처리 방지`
- `docs: 앱 종료 정책과 개인정보 범위 설명`
- `test: 수면 라이프사이클 상태 전이 검증`

Avoid vague words such as `작업`, `반영`, `수정함`, `업데이트`.

## Commit Scope Rules

- One commit should represent one logical change unit.
- Runtime safety changes should include related tests in the same commit.
- Documentation-only changes can be separate when they do not depend on code.
- Generated or project metadata files should be included only when they are required by the source changes.

## Pre-Commit Checks

For code changes, prefer:

```sh
xcodebuild -project SleepGuard/SleepGuard.xcodeproj -scheme SleepGuard -destination 'platform=macOS' test
git diff --check
```

If checks were not run, state that clearly in the final response.
