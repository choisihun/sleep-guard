import XCTest
@testable import SleepGuard

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testDefaultSettingsCleanOnSystemSleepButDoNotAutoQuitHighImpactApps() {
        let settings = AppSettings()

        XCTAssertTrue(settings.autoCleanOnWillSleep)
        XCTAssertFalse(settings.shouldAutoQuitHighImpactAppsBeforeSleep)
    }

    func testSaveRollsBackWhenLoginItemSyncFails() async {
        let settings = AppSettings(launchAtLogin: false)
        let store = RecordingSettingsStore(settings: settings)
        let loginItemManager = RecordingLoginItemManager(enableError: CommandError.unknown("login failed"))
        let viewModel = SettingsViewModel(settingsStore: store, loginItemManager: loginItemManager)

        await viewModel.load()
        viewModel.settings?.launchAtLogin = true
        await viewModel.save()

        XCTAssertEqual(store.saveCount, 0)
        XCTAssertEqual(viewModel.settings?.launchAtLogin, false)
        XCTAssertTrue(viewModel.message.contains("login failed"))
    }

    func testSaveSyncsLoginItemBeforePersistingSettings() async {
        let settings = AppSettings(launchAtLogin: false)
        let operationLog = OperationLog()
        let store = RecordingSettingsStore(settings: settings, operationLog: operationLog)
        let loginItemManager = RecordingLoginItemManager(operationLog: operationLog)
        let viewModel = SettingsViewModel(settingsStore: store, loginItemManager: loginItemManager)

        await viewModel.load()
        viewModel.settings?.launchAtLogin = true
        await viewModel.save()

        XCTAssertEqual(operationLog.events, ["enableLoginItem", "saveSettings"])
        XCTAssertEqual(store.saveCount, 1)
        XCTAssertEqual(loginItemManager.isEnabled, true)
    }
}

@MainActor
private final class RecordingSettingsStore: SettingsStoring {
    var settings: AppSettings
    var saveCount = 0
    private let operationLog: OperationLog?

    init(settings: AppSettings, operationLog: OperationLog? = nil) {
        self.settings = settings
        self.operationLog = operationLog
    }

    func fetchOrCreate() async throws -> AppSettings {
        settings
    }

    func save(_ settings: AppSettings) async throws {
        saveCount += 1
        operationLog?.events.append("saveSettings")
        self.settings = settings
    }
}

private final class RecordingLoginItemManager: LoginItemManaging {
    var isEnabled = false
    var enableError: Error?
    var disableError: Error?
    private let operationLog: OperationLog?

    init(enableError: Error? = nil, disableError: Error? = nil, operationLog: OperationLog? = nil) {
        self.enableError = enableError
        self.disableError = disableError
        self.operationLog = operationLog
    }

    func enable() throws {
        if let enableError { throw enableError }
        operationLog?.events.append("enableLoginItem")
        isEnabled = true
    }

    func disable() throws {
        if let disableError { throw disableError }
        operationLog?.events.append("disableLoginItem")
        isEnabled = false
    }
}

private final class OperationLog {
    var events: [String] = []
}
