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

    func testAutoHighImpactAppsAreTerminatedWhenSettingEnabled() async {
        let renderer = RunningAppInfo(
            bundleId: "com.example.Renderer",
            displayName: "Renderer",
            executableURL: nil,
            bundleURL: URL(fileURLWithPath: "/Applications/Renderer.app"),
            processIdentifier: 124,
            activationPolicyRawValue: NSApplication.ActivationPolicy.regular.rawValue,
            isTerminated: false,
            isHidden: false
        )
        let environment = LifecycleTestEnvironment(
            settings: AppSettings(autoCleanOnWillSleep: true, autoQuitHighImpactAppsBeforeSleep: true),
            additionalRunningApps: [renderer],
            highImpactBundleIds: ["com.example.Renderer"]
        )

        await environment.controller.cleanAndSleep()

        XCTAssertEqual(
            Set(environment.terminator.terminatedApps.compactMap(\.bundleId)),
            Set(["com.example.Utility", "com.example.Renderer"])
        )
    }

    func testAutoHighImpactSkipsBrowserApps() async {
        let chrome = RunningAppInfo(
            bundleId: "com.google.Chrome",
            displayName: "Google Chrome",
            executableURL: nil,
            bundleURL: URL(fileURLWithPath: "/Applications/Google Chrome.app"),
            processIdentifier: 125,
            activationPolicyRawValue: NSApplication.ActivationPolicy.regular.rawValue,
            isTerminated: false,
            isHidden: false
        )
        let environment = LifecycleTestEnvironment(
            settings: AppSettings(autoCleanOnWillSleep: true, autoQuitHighImpactAppsBeforeSleep: true),
            additionalRunningApps: [chrome],
            highImpactBundleIds: ["com.google.Chrome"]
        )

        await environment.controller.cleanAndSleep()

        XCTAssertEqual(environment.terminator.terminatedApps.map(\.bundleId), ["com.example.Utility"])
    }

    func testAnalyzeNowDoesNotResetRiskBeforeAssertionsAreParsed() async {
        let environment = LifecycleTestEnvironment(settings: AppSettings(autoCleanOnWillSleep: true))
        let controller = environment.controller
        environment.pmsetRunner.assertionsOutput = Self.assertionLog(count: 7)

        await controller.analyzeNow()
        XCTAssertEqual(controller.currentRisk.level, .caution)

        var observedLevelDuringPMSetRead: SleepRiskLevel?
        environment.pmsetRunner.onAssertionsStarted = {
            observedLevelDuringPMSetRead = await MainActor.run {
                controller.currentRisk.level
            }
        }

        await controller.analyzeNow()

        XCTAssertEqual(observedLevelDuringPMSetRead, .caution)
        XCTAssertEqual(controller.currentRisk.level, .caution)
    }

    func testRefreshCurrentStateCanPreserveExistingRisk() async {
        let environment = LifecycleTestEnvironment(settings: AppSettings(autoCleanOnWillSleep: true))
        let controller = environment.controller
        environment.pmsetRunner.assertionsOutput = Self.assertionLog(count: 7)

        await controller.analyzeNow()
        XCTAssertEqual(controller.currentRisk.level, .caution)

        await controller.refreshCurrentState(updateRisk: false)

        XCTAssertEqual(controller.currentRisk.level, .caution)
    }

    func testManagedAppsAutoSyncRefreshesRecommendationsWhileVisible() async throws {
        let renderer = RunningAppInfo(
            bundleId: "com.example.Renderer",
            displayName: "Renderer",
            executableURL: nil,
            bundleURL: URL(fileURLWithPath: "/Applications/Renderer.app"),
            processIdentifier: 124,
            activationPolicyRawValue: NSApplication.ActivationPolicy.regular.rawValue,
            isTerminated: false,
            isHidden: false
        )
        let environment = LifecycleTestEnvironment(
            settings: AppSettings(autoCleanOnWillSleep: true),
            highImpactBundleIds: ["com.example.Renderer"]
        )
        let viewModel = ManagedAppsViewModel(
            controller: environment.controller,
            store: environment.managedAppStore,
            autoSyncIntervalNanoseconds: 20_000_000
        )

        let syncTask = Task {
            await viewModel.autoSyncCurrentState()
        }
        try await Task.sleep(nanoseconds: 30_000_000)

        XCTAssertTrue(viewModel.energyRecommendations.isEmpty)

        environment.runningAppProvider.apps.append(renderer)
        try await Task.sleep(nanoseconds: 80_000_000)

        syncTask.cancel()
        await syncTask.value

        XCTAssertEqual(viewModel.energyRecommendations.compactMap(\.app.bundleId), ["com.example.Renderer"])
    }

    func testReportsAutoSyncRefreshesHistoryWhileVisible() async throws {
        let environment = LifecycleTestEnvironment(settings: AppSettings(autoCleanOnWillSleep: true))
        let viewModel = ReportsViewModel(
            controller: environment.controller,
            autoSyncIntervalNanoseconds: 20_000_000
        )

        let syncTask = Task {
            await viewModel.autoSyncHistory()
        }
        try await Task.sleep(nanoseconds: 30_000_000)

        XCTAssertTrue(environment.controller.recentReports.isEmpty)

        let session = try await environment.sessionStore.create(
            startedAt: Date(),
            batteryBefore: 80,
            wasManualSleep: false
        )
        _ = try await environment.reportStore.save(
            draft: SleepReportDraft(
                riskScore: 0,
                riskLevel: .good,
                summaryText: "테스트 리포트",
                recommendations: [],
                darkWakeCount: 0,
                wakeRequestCount: 0,
                assertionCount: 0,
                bluetoothDelayCount: 0,
                tcpKeepAliveCount: 0,
                rawPMSetExcerpt: "",
                topSuspectNames: [],
                eventAnalysisStatus: .available,
                pmsetDiagnostics: nil
            ),
            sessionId: session.id
        )
        try await Task.sleep(nanoseconds: 80_000_000)

        syncTask.cancel()
        await syncTask.value

        XCTAssertEqual(environment.controller.recentReports.map(\.summaryText), ["테스트 리포트"])
    }

    private static func assertionLog(count: Int) -> String {
        (0..<count)
            .map {
                let second = String(format: "%02d", $0)
                return "2026-05-22 23:16:\(second) +0900 Assertions            PID \($0 + 100)(TestApp\($0)) PreventUserIdleSystemSleep named: \"test\""
            }
            .joined(separator: "\n")
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
    let energyImpactProvider: LifecycleEnergyImpactProvider
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

    init(
        settings: AppSettings,
        additionalRunningApps: [RunningAppInfo] = [],
        highImpactBundleIds: Set<String> = []
    ) {
        runningAppProvider = LifecycleRunningAppProvider(apps: [app] + additionalRunningApps)
        energyImpactProvider = LifecycleEnergyImpactProvider(highImpactBundleIds: highImpactBundleIds)
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
    private let highImpactBundleIds: Set<String>

    init(highImpactBundleIds: Set<String> = []) {
        self.highImpactBundleIds = highImpactBundleIds
    }

    func impacts(for apps: [RunningAppInfo]) async -> [AppEnergyImpact] {
        apps.map {
            let isHighImpact = $0.bundleId.map { highImpactBundleIds.contains($0) } ?? false
            return AppEnergyImpact(
                app: $0,
                cpuPercent: isHighImpact ? 4 : 1,
                memoryMB: isHighImpact ? 900 : 1,
                score: isHighImpact ? 60 : 10,
                level: isHighImpact ? .high : .medium,
                reasons: []
            )
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
    var assertionsOutput = ""
    var onAssertionsStarted: (() async -> Void)?

    func assertions() async throws -> String {
        assertionsCallCount += 1
        await onAssertionsStarted?()
        return assertionsOutput
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
