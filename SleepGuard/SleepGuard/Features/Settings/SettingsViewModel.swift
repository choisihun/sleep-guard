import AppKit
import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var settings: AppSettings?
    @Published var message = ""

    private let settingsStore: SettingsStoring
    private let loginItemManager: LoginItemManaging
    private var persistedSnapshot: SettingsSnapshot?

    init(settingsStore: SettingsStoring, loginItemManager: LoginItemManaging) {
        self.settingsStore = settingsStore
        self.loginItemManager = loginItemManager
    }

    func load() async {
        do {
            settings = try await settingsStore.fetchOrCreate()
            if let settings {
                persistedSnapshot = SettingsSnapshot(settings)
            }
        } catch {
            message = error.localizedDescription
        }
    }

    func save() async {
        guard let settings else { return }
        let previousSnapshot = persistedSnapshot ?? SettingsSnapshot(settings)
        let requestedSnapshot = SettingsSnapshot(settings)
        do {
            if requestedSnapshot.launchAtLogin != previousSnapshot.launchAtLogin {
                try syncLoginItem(requestedSnapshot.launchAtLogin)
            }
            try await settingsStore.save(settings)
            persistedSnapshot = requestedSnapshot
            message = "설정을 저장했습니다."
        } catch {
            if requestedSnapshot.launchAtLogin != previousSnapshot.launchAtLogin {
                try? syncLoginItem(previousSnapshot.launchAtLogin)
            }
            previousSnapshot.apply(to: settings)
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

private struct SettingsSnapshot {
    var launchAtLogin: Bool
    var autoCleanOnWillSleep: Bool
    var showWakeReportNotification: Bool
    var enableForceTerminate: Bool
    var defaultTerminationTimeoutSeconds: Double
    var maxAppsToQuitBeforeSleep: Int?
    var restoreAppsOnWake: Bool
    var includePMSetRawExcerpt: Bool
    var showDockIcon: Bool

    init(_ settings: AppSettings) {
        launchAtLogin = settings.launchAtLogin
        autoCleanOnWillSleep = settings.autoCleanOnWillSleep
        showWakeReportNotification = settings.showWakeReportNotification
        enableForceTerminate = settings.enableForceTerminate
        defaultTerminationTimeoutSeconds = settings.defaultTerminationTimeoutSeconds
        maxAppsToQuitBeforeSleep = settings.maxAppsToQuitBeforeSleep
        restoreAppsOnWake = settings.restoreAppsOnWake
        includePMSetRawExcerpt = settings.includePMSetRawExcerpt
        showDockIcon = settings.showDockIcon
    }

    func apply(to settings: AppSettings) {
        settings.launchAtLogin = launchAtLogin
        settings.autoCleanOnWillSleep = autoCleanOnWillSleep
        settings.showWakeReportNotification = showWakeReportNotification
        settings.enableForceTerminate = enableForceTerminate
        settings.defaultTerminationTimeoutSeconds = defaultTerminationTimeoutSeconds
        settings.maxAppsToQuitBeforeSleep = maxAppsToQuitBeforeSleep
        settings.restoreAppsOnWake = restoreAppsOnWake
        settings.includePMSetRawExcerpt = includePMSetRawExcerpt
        settings.showDockIcon = showDockIcon
    }
}
