import AppIntents
import Foundation

struct CleanAndSleepIntent: AppIntent {
    static var title: LocalizedStringResource = "정리하고 잠자기"
    static var description = IntentDescription("Sleep Guard가 관리 앱을 정리한 뒤 Mac을 잠자기 모드로 전환합니다.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = try await SleepGuardShortcutCoordinator.shared.cleanAndSleep()
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct SleepGuardShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CleanAndSleepIntent(),
            phrases: [
                "\(.applicationName)로 잠자기",
                "\(.applicationName)에서 정리하고 잠자기",
                "\(.applicationName) 잠자기"
            ],
            shortTitle: "정리하고 잠자기",
            systemImageName: "moon.zzz.fill"
        )
    }
}
