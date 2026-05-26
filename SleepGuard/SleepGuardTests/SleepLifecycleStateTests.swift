import AppKit
import XCTest
@testable import SleepGuard

@MainActor
final class SleepLifecycleStateTests: XCTestCase {
    func testScreensDidSleepIsSkippedWhileSystemIsSleeping() async {
        let environment = LifecycleTestEnvironment(settings: AppSettings(autoCleanOnWillSleep: true))
        let controller = environment.controller

        await controller.handlePowerEvent(.willSleep)
        await controller.handlePowerEvent(.screensDidSleep)

        XCTAssertEqual(controller.lifecycleState, .sleeping)
        XCTAssertEqual(environment.pmsetRunner.assertionsCallCount, 1)
        XCTAssertTrue(controller.lastActionMessage.contains("건너뜁니다"))
    }

    func testDuplicateDidWakeDoesNotCreateSecondReport() async {
        let environment = LifecycleTestEnvironment(settings: AppSettings(autoCleanOnWillSleep: true))
        let controller = environment.controller

        await controller.handlePowerEvent(.willSleep)
        await controller.handlePowerEvent(.didWake)
        await controller.handlePowerEvent(.didWake)

        XCTAssertEqual(controller.lifecycleState, .idle)
        XCTAssertEqual(environment.reportStore.savedReports.count, 1)
    }

    func testManualCleanAndSleepTerminatesManagedAppsAndRequestsSleepNow() async {
        let environment = LifecycleTestEnvironment(settings: AppSettings(autoCleanOnWillSleep: true))

        await environment.controller.cleanAndSleep()

        XCTAssertEqual(environment.terminator.terminatedApps.map(\.bundleId), ["com.example.Utility"])
        XCTAssertEqual(environment.pmsetRunner.sleepNowCallCount, 1)
        XCTAssertEqual(environment.controller.lifecycleState, .sleeping)
    }
}

@MainActor
private final class LifecycleTestEnvironment {
    let app = RunningAppInfo(
        bundleId: "com.example.Utility",
        displayName: "Utility",
        executableURL: nil,
        bundleURL: URL(fileURLWithPath: "/Applications/Utility.app"),
        processIdentifier: 123,
        activationPolicyRawValue: NSApplication.ActivationPolicy.regular.rawValue,
        isTerminated: false,
        isHidden: false
    )
    let batteryMonitor = LifecycleBatteryMonitor()
    let runningAppProvider: LifecycleRunningAppProvider
    let energyImpactProvider = LifecycleEnergyImpactProvider()
    let terminator = LifecycleAppTerminator()
    let restorer = LifecycleAppRestorer()
    let pmsetRunner = LifecyclePMSetRunner()
    let sessionStore = LifecycleSessionStore()
    let reportStore = LifecycleReportStore()
    let managedAppStore: LifecycleManagedAppStore
    let settingsStore: LifecycleSettingsStore
    let snapshotStore = LifecycleSnapshotStore()
    let notificationService = LifecycleNotificationService()
    let logCollector = LifecyclePMSetLogCollector()
    let controller: SleepGuardController

    init(settings: AppSettings) {
        runningAppProvider = LifecycleRunningAppProvider(apps: [app])
        managedAppStore = LifecycleManagedAppStore(
            apps: [
                ManagedApp(
                    bundleId: "com.example.Utility",
                    displayName: "Utility",
                    appURLString: app.bundleURL?.absoluteString,
                    isEnabled: true,
                    shouldQuitBeforeSleep: true,
                    shouldRestoreAfterWake: true,
                    allowsForceTerminate: false,
                    categoryRawValue: ManagedAppCategory.utility.rawValue
                )
            ]
        )
        settingsStore = LifecycleSettingsStore(settings: settings)
        controller = SleepGuardController(
            batteryMonitor: batteryMonitor,
            runningAppProvider: runningAppProvider,
            energyImpactProvider: energyImpactProvider,
            protectedAppPolicy: ProtectedAppPolicy(configuration: .empty),
            appTerminator: terminator,
            appRestorer: restorer,
            pmsetRunner: pmsetRunner,
            logParser: PMSetLogParser(),
            logCollector: logCollector,
            reportGenerator: SleepReportGenerator(),
            drainCalculator: BatteryDrainCalculator(),
            sessionStore: sessionStore,
            reportStore: reportStore,
            managedAppStore: managedAppStore,
            settingsStore: settingsStore,
            snapshotStore: snapshotStore,
            notificationService: notificationService
        )
    }
}

private final class LifecycleBatteryMonitor: BatteryMonitor {
    func currentBatteryInfo() -> BatteryInfo? {
        BatteryInfo(percent: 80, isCharging: false, powerSource: .battery, timeRemainingMinutes: nil, timestamp: Date())
    }
}

private final class LifecycleRunningAppProvider: RunningAppProvider {
    var apps: [RunningAppInfo]

    init(apps: [RunningAppInfo]) {
        self.apps = apps
    }

    func runningApplications() -> [RunningAppInfo] {
        apps
    }
}

private final class LifecycleEnergyImpactProvider: AppEnergyImpactProviding {
    func impacts(for apps: [RunningAppInfo]) async -> [AppEnergyImpact] {
        apps.map {
            AppEnergyImpact(app: $0, cpuPercent: 1, memoryMB: 1, score: 10, level: .medium, reasons: [])
        }
    }
}

private final class LifecycleAppTerminator: AppTerminating {
    private(set) var terminatedApps: [RunningAppInfo] = []

    func terminate(
        app: RunningAppInfo,
        configuration: ManagedAppConfiguration?,
        globalForceEnabled: Bool,
        mode: TerminationMode
    ) async -> TerminationResult {
        terminatedApps.append(app)
        return .success
    }
}

private final class LifecycleAppRestorer: AppRestoring {
    func restore(record: RunningAppRecord, shouldRestore: Bool) async -> RestoreResult {
        shouldRestore ? .success : .skippedByUserSetting
    }
}

private final class LifecyclePMSetRunner: PMSetCommandRunning {
    private(set) var assertionsCallCount = 0
    private(set) var sleepNowCallCount = 0

    func assertions() async throws -> String {
        assertionsCallCount += 1
        return ""
    }

    func log() async throws -> String {
        ""
    }

    func sched() async throws -> String {
        ""
    }

    func sleepNow() async throws {
        sleepNowCallCount += 1
    }
}

@MainActor
private final class LifecycleSessionStore: SleepSessionStoring {
    private var sessions: [SleepSession] = []

    func create(startedAt: Date, batteryBefore: Int, wasManualSleep: Bool) async throws -> SleepSession {
        let session = SleepSession(sleepStartedAt: startedAt, batteryBefore: batteryBefore, wasManualSleep: wasManualSleep)
        sessions.insert(session, at: 0)
        return session
    }

    func updateAfterWake(_ session: SleepSession, wokeAt: Date, batteryAfter: Int, drain: BatteryDrainResult) async throws {
        session.wokeAt = wokeAt
        session.batteryAfter = batteryAfter
        session.drainPercent = drain.drainPercent
        session.drainPerHour = drain.drainPerHour
        session.durationSeconds = drain.durationSeconds
    }

    func fetchRecent(limit: Int) async throws -> [SleepSession] {
        Array(sessions.prefix(limit))
    }

    func fetch(id: UUID) async throws -> SleepSession? {
        sessions.first { $0.id == id }
    }
}

@MainActor
private final class LifecycleReportStore: SleepReportStoring {
    private(set) var savedReports: [SleepReport] = []

    func save(draft: SleepReportDraft, sessionId: UUID) async throws -> SleepReport {
        let report = SleepReport(
            sessionId: sessionId,
            riskScore: draft.riskScore,
            riskLevelRawValue: draft.riskLevel.rawValue,
            summaryText: draft.summaryText,
            recommendationTexts: draft.recommendations,
            darkWakeCount: draft.darkWakeCount,
            wakeRequestCount: draft.wakeRequestCount,
            assertionCount: draft.assertionCount,
            bluetoothDelayCount: draft.bluetoothDelayCount,
            tcpKeepAliveCount: draft.tcpKeepAliveCount,
            rawPMSetExcerpt: draft.rawPMSetExcerpt,
            topSuspectNames: draft.topSuspectNames,
            eventAnalysisStatusRawValue: draft.eventAnalysisStatus.rawValue,
            pmsetDiagnostics: draft.pmsetDiagnostics
        )
        savedReports.append(report)
        return report
    }

    func update(reportId: UUID, draft: SleepReportDraft) async throws -> SleepReport {
        throw SleepReportStoreError.reportNotFound
    }

    func updatePMSetDiagnostics(reportId: UUID, diagnostics: PMSetLogDiagnostics) async throws -> SleepReport {
        throw SleepReportStoreError.reportNotFound
    }

    func fetchRecent(limit: Int) async throws -> [SleepReport] {
        Array(savedReports.prefix(limit))
    }

    func fetch(id: UUID) async throws -> SleepReport? {
        savedReports.first { $0.id == id }
    }

    func fetch(sessionId: UUID) async throws -> SleepReport? {
        savedReports.first { $0.sessionId == sessionId }
    }
}

@MainActor
private final class LifecycleManagedAppStore: ManagedAppStoring {
    var apps: [ManagedApp]

    init(apps: [ManagedApp]) {
        self.apps = apps
    }

    func fetchAll() async throws -> [ManagedApp] {
        apps
    }

    func fetchEnabled() async throws -> [ManagedApp] {
        apps.filter(\.isEnabled)
    }

    func fetch(bundleId: String) async throws -> ManagedApp? {
        apps.first { $0.bundleId == bundleId }
    }

    func addFromRunningApp(_ app: RunningAppInfo) async throws -> ManagedApp? {
        nil
    }

    func save() async throws {}

    func delete(_ app: ManagedApp) async throws {}
}

@MainActor
private final class LifecycleSettingsStore: SettingsStoring {
    var settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    func fetchOrCreate() async throws -> AppSettings {
        settings
    }

    func save(_ settings: AppSettings) async throws {
        self.settings = settings
    }
}

@MainActor
private final class LifecycleSnapshotStore: AppSnapshotStoring {
    private var snapshots: [AppSnapshot] = []

    func save(snapshot: AppSnapshot) async throws {
        snapshots.append(snapshot)
    }

    func latest(sessionId: UUID) async throws -> AppSnapshot? {
        snapshots.last { $0.sessionId == sessionId }
    }
}

private final class LifecycleNotificationService: UserNotificationServicing {
    func requestAuthorization() async {}

    func showWakeReportNotification(report: SleepReport, session: SleepSession) {}
}

private final class LifecyclePMSetLogCollector: PMSetLogCollecting {
    func collect(sessionStart: Date?, sessionEnd: Date?, includeRawExcerpt: Bool) async -> PMSetLogCollection {
        PMSetLogCollection(
            rawLog: "",
            rawExcerpt: "",
            events: [],
            status: .available,
            diagnostics: PMSetLogDiagnostics(rawLogLineCount: 0)
        )
    }
}
