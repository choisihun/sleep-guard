# Sleep Guard

Sleep Guard는 MacBook이 잠들기 전 사용자가 허용한 앱을 안전하게 종료하고, 깨어난 뒤 다시 실행하며, `pmset` 로그와 배터리 변화를 분석해 수면 리포트를 생성하는 macOS 네이티브 메뉴바 앱입니다.

## Purpose

- 잠자기 전 배터리 소모 가능성이 높은 앱을 사용자가 승인한 범위에서 정리합니다.
- 깨어난 뒤 종료했던 앱을 복구하고, 수면 중 배터리 감소와 `pmset` 이벤트를 리포트로 남깁니다.
- 오래 켜져 있는 메뉴바 앱으로 동작하므로 런타임 안정성과 사용자 데이터 보호를 우선합니다.

## Project

- Product Name: Sleep Guard
- Bundle Identifier: `com.sihun.sleepguard`
- Minimum Target: macOS 14+
- Stack: Swift, SwiftUI, AppKit, SwiftData, XCTest, Swift Testing

## Permissions and System Access

- `pmset` 조회: `/usr/bin/pmset`으로 assertions, schedule, sleep/wake 로그를 읽습니다.
- Sleep 요청: 수동 정리 후 잠자기 기능은 `pmset sleepnow`를 호출합니다.
- Shortcuts: macOS 단축어 앱에 "정리하고 잠자기" 액션을 제공해 같은 정리/잠자기 흐름을 실행합니다.
- Login Item: 첫 실행 시 "로그인 시 실행"을 켜도록 안내하고, 설정에서 켜면 macOS ServiceManagement API로 login item을 등록합니다.
- Notifications: wake 리포트 알림을 표시하기 위해 사용자 알림 권한을 요청합니다.
- 앱 복구: 저장된 로컬 `.app` 번들 URL 또는 bundle identifier를 사용해 `NSWorkspace`로 앱을 엽니다.

## App Termination Policy

- Sleep Guard는 앱이 실행 중일 때 시스템 잠자기 또는 덮개 닫힘 이벤트를 받으면 잠자기 전 자동 정리를 실행합니다.
- 기본적으로 사용자가 관리 앱으로 추가하고 "잠자기 전 종료"를 켠 앱만 종료 대상으로 삼습니다.
- 사용자가 "배터리 영향 높은 앱 자동 정리"를 켜면 관리 앱이 아니어도 고영향 앱을 graceful 종료 후보에 포함할 수 있습니다.
- 시스템 앱, bundle id가 없는 프로세스, 보호 목록의 앱과 프로세스는 종료하지 않습니다.
- 브라우저, 개발 도구, 문서 작업 앱은 자동 고영향 앱 정리 대상에서 제외합니다. 필요하면 사용자가 직접 관리 앱으로 추가해야 합니다.
- 기본 종료 방식은 graceful terminate입니다. 앱이 timeout 안에 종료되지 않으면 기본적으로 더 진행하지 않습니다.
- 강제 종료는 전역 설정, 앱별 opt-in, 보호 정책 allowlist를 모두 통과해야만 실행됩니다. allowlist 기본값은 비어 있습니다.
- 브라우저, 개발 도구, 문서 작업 앱 계열은 저장되지 않은 작업 손실 가능성이 크므로 force terminate 대상에서 제외하는 정책을 권장합니다.

## Restore and Log Safety

- 앱 복구는 `file://` URL의 `.app` 번들만 허용하며 `/Applications`, `/System/Applications`, `~/Applications` 아래 경로만 신뢰합니다.
- `pmset -g log`는 출력이 커질 수 있으므로 실행 중 stdout/stderr를 drain하고, 앱에서는 수면 세션 window 또는 최신 tail만 보관합니다.
- 리포트에는 분석에 필요한 excerpt와 진단 정보만 저장합니다. 전체 `pmset` 로그를 영구 저장하지 않습니다.

## Build

```sh
xcodebuild -project SleepGuard/SleepGuard.xcodeproj -scheme SleepGuard -destination 'platform=macOS' build
```

## Test

```sh
xcodebuild -project SleepGuard/SleepGuard.xcodeproj -scheme SleepGuard -destination 'platform=macOS' test
```

## Privacy

- 저장 데이터는 SwiftData 로컬 저장소에 남습니다.
- 저장 범위는 수면 세션 시간, 배터리 수치, 리포트 요약, 제한된 `pmset` excerpt, 종료/복구 앱 snapshot입니다.
- Sleep Guard는 네트워크로 로그나 앱 목록을 전송하지 않습니다.
