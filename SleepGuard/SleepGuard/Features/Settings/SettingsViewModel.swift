import AppKit
import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var settings: AppSettings?
    @Published var message = ""

    private let settingsStore: SettingsStoring
    private let loginItemManager: LoginItemManaging

    init(settingsStore: SettingsStoring, loginItemManager: LoginItemManaging) {
        self.settingsStore = settingsStore
        self.loginItemManager = loginItemManager
    }

    func load() async {
        do {
            settings = try await settingsStore.fetchOrCreate()
        } catch {
            message = error.localizedDescription
        }
    }

    func save() async {
        guard let settings else { return }
        do {
            try await settingsStore.save(settings)
            try syncLoginItem(settings.launchAtLogin)
            message = "설정을 저장했습니다."
        } catch {
            message = error.localizedDescription
        }
    }

    private func syncLoginItem(_ enabled: Bool) throws {
        if enabled {
            try loginItemManager.enable()
        } else {
            try loginItemManager.disable()
        }
    }
}
