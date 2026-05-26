import Foundation

@MainActor
final class SleepGuardShortcutCoordinator {
    static let shared = SleepGuardShortcutCoordinator()

    private var container: AppDependencyContainer?

    private init() {}

    func register(container: AppDependencyContainer) {
        self.container = container
    }

    func cleanAndSleep() async throws -> String {
        let container = try activeContainer()
        await container.controller.cleanAndSleep()

        if !container.controller.lastActionMessage.isEmpty {
            return container.controller.lastActionMessage
        }
        return "앱을 정리하고 Mac을 잠자기 모드로 전환합니다."
    }

    private func activeContainer() throws -> AppDependencyContainer {
        if let container {
            return container
        }

        let container = try AppDependencyContainer()
        self.container = container
        return container
    }
}
