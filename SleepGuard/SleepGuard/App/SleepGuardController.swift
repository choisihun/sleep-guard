import Combine
import Foundation

enum SleepLifecycleState: String, Equatable {
    case idle
    case preparing
    case sleeping
    case waking
}

enum SleepLifecycleEvent {
    case willSleep
    case didWake
    case screensDidSleep
}

@MainActor
final class SleepGuardController: ObservableObject {
    @Published private(set) var batteryInfo: BatteryInfo = .unknown
    @Published private(set) var runningApps: [RunningAppInfo] = []
    @Published private(set) var appEnergyImpacts: [AppEnergyImpact] = []
    @Published private(set) var suspiciousApps: [RunningAppInfo] = []
    @Published private(set) var currentRisk = SleepRiskResult(score: 0, level: .good)
    @Published private(set) var recentSessions: [SleepSession] = []
    @Published private(set) var recentReports: [SleepReport] = []
    @Published private(set) var parsedEvents: [PMSetEvent] = []
    @Published private(set) var rawLogText = ""
    @Published private(set) var assertionSummary = "분석 전"
    @Published private(set) var lastActionMessage = ""
    @Published private(set) var isWorking = false
    @Published private(set) var reanalyzingReportId: UUID?
    @Published private(set) var lifecycleState: SleepLifecycleState = .idle

    private let batteryMonitor: BatteryMonitor
    private let runningAppProvider: RunningAppProvider
    private let energyImpactProvider: AppEnergyImpactProviding
    private let policy: ProtectedAppPolicy
    private let appTerminator: AppTerminating
    private let appRestorer: AppRestoring
    private let pmsetRunner: PMSetCommandRunning
    private let logParser: PMSetLogParser
    private let logCollector: PMSetLogCollecting
    private let reportGenerator: SleepReportGenerator
    private let drainCalculator: BatteryDrainCalculator
    private let sessionStore: SleepSessionStoring
    private let reportStore: SleepReportStoring
    private let managedAppStore: ManagedAppStoring
    private let settingsStore: SettingsStoring
    private let snapshotStore: AppSnapshotStoring
    private let notificationService: UserNotificationServicing

    private var activeSession: SleepSession?
    private var lastTerminatedRecords: [RunningAppRecord] = []
    private let suspiciousAppDetector: SuspiciousAppDetector
    private var lifecycleEventQueue: [SleepLifecycleEvent] = []
    private var isProcessingLifecycleEvent = false

    init(
        batteryMonitor: BatteryMonitor,
        runningAppProvider: RunningAppProvider,
        energyImpactProvider: AppEnergyImpactProviding,
        protectedAppPolicy: ProtectedAppPolicy,
        appTerminator: AppTerminating,
        appRestorer: AppRestoring,
        pmsetRunner: PMSetCommandRunning,
        logParser: PMSetLogParser,
        logCollector: PMSetLogCollecting? = nil,
        reportGenerator: SleepReportGenerator,
        drainCalculator: BatteryDrainCalculator,
        sessionStore: SleepSessionStoring,
        reportStore: SleepReportStoring,
        managedAppStore: ManagedAppStoring,
        settingsStore: SettingsStoring,
        snapshotStore: AppSnapshotStoring,
        notificationService: UserNotificationServicing
    ) {
        self.batteryMonitor = batteryMonitor
        self.runningAppProvider = runningAppProvider
        self.energyImpactProvider = energyImpactProvider
        self.policy = protectedAppPolicy
        self.suspiciousAppDetector = SuspiciousAppDetector(policy: protectedAppPolicy)
        self.appTerminator = appTerminator
        self.appRestorer = appRestorer
        self.pmsetRunner = pmsetRunner
        self.logParser = logParser
        self.logCollector = logCollector ?? PMSetLogCollector(commandRunner: pmsetRunner)
        self.reportGenerator = reportGenerator
        self.drainCalculator = drainCalculator
        self.sessionStore = sessionStore
        self.reportStore = reportStore
        self.managedAppStore = managedAppStore
        self.settingsStore = settingsStore
        self.snapshotStore = snapshotStore
        self.notificationService = notificationService
    }

    func bootstrap() async {
        await notificationService.requestAuthorization()
        await refreshCurrentState()
        await reloadHistory()
    }

    func refreshCurrentState(updateRisk: Bool = true) async {
        batteryInfo = batteryMonitor.currentBatteryInfo() ?? .unknown
        runningApps = runningAppProvider.runningApplications()
        let managed = (try? await managedAppStore.fetchAll()) ?? []
        appEnergyImpacts = await energyImpactProvider.impacts(for: runningApps)
        suspiciousApps = suspiciousAppDetector.suspiciousApps(
            runningApps: runningApps,
            managedApps: managed,
            energyImpacts: appEnergyImpacts
        )
        if updateRisk {
            currentRisk = SleepRiskAnalyzer().analyze(
                SleepRiskInput(
                    drainPercent: 0,
                    drainPerHour: 0,
                    darkWakeCount: 0,
                    wakeRequestCount: 0,
                    assertionCount: 0,
                    bluetoothDelayCount: 0,
                    tcpKeepAliveCount: 0,
                    suspiciousProcessNames: suspiciousApps.map(\.displayName)
                )
            )
        }
    }

    func canShowInManagedAppRecommendations(_ app: RunningAppInfo) -> Bool {
        !policy.isProtected(app)
    }

    func analyzeNow() async {
        guard lifecycleState == .idle else {
            lastActionMessage = "전원 이벤트 처리 중이라 현재 분석을 건너뜁니다."
            return
        }
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        await refreshCurrentState(updateRisk: false)
        do {
            let assertions = try await pmsetRunner.assertions()
            rawLogText = assertions
            let events = logParser.parse(assertions)
            parsedEvents = events
            let assertionEvents = events.filter { $0.category == .assertion }
            let names = assertionEvents.compactMap(\.processName).uniqued()
            assertionSummary = names.isEmpty ? "현재 주요 sleep 방해 assertion은 보이지 않습니다." : names.joined(separator: ", ")
            currentRisk = SleepRiskAnalyzer().analyze(
                SleepRiskInput(
                    drainPercent: 0,
                    drainPerHour: 0,
                    darkWakeCount: 0,
                    wakeRequestCount: 0,
                    assertionCount: assertionEvents.count,
                    bluetoothDelayCount: events.filter { $0.category == .bluetooth }.count,
                    tcpKeepAliveCount: events.filter(\.isTCPKeepAliveActive).count,
                    suspiciousProcessNames: names + suspiciousApps.map(\.displayName)
                )
            )
            lastActionMessage = "현재 상태 분석을 완료했습니다."
        } catch {
            assertionSummary = "assertions 조회 실패"
            lastActionMessage = "분석 실패: \(error.localizedDescription)"
        }
    }

    func cleanAndSleep() async {
        guard lifecycleState == .idle, !isWorking else { return }
        lifecycleState = .preparing
        await prepareForSleep(wasManualSleep: true, shouldEnterSleep: true)
        lifecycleState = .sleeping
    }

    func handleWillSleep() async {
        await handlePowerEvent(.willSleep)
    }

    func handleDidWake() async {
        await handlePowerEvent(.didWake)
    }

    func handleScreensDidSleep() async {
        await handlePowerEvent(.screensDidSleep)
    }

    func handlePowerEvent(_ event: SleepLifecycleEvent) async {
        lifecycleEventQueue.append(event)
        guard !isProcessingLifecycleEvent else { return }

        isProcessingLifecycleEvent = true
        defer { isProcessingLifecycleEvent = false }

        while !lifecycleEventQueue.isEmpty {
            let nextEvent = lifecycleEventQueue.removeFirst()
            await processLifecycleEvent(nextEvent)
        }
    }

    private func processLifecycleEvent(_ event: SleepLifecycleEvent) async {
        switch event {
        case .willSleep:
            guard lifecycleState == .idle else {
                lastActionMessage = "이미 수면 전환 처리 중입니다."
                return
            }
            lifecycleState = .preparing
            await handleWillSleepCore()
            lifecycleState = .sleeping

        case .didWake:
            guard lifecycleState != .waking else {
                lastActionMessage = "이미 wake 처리 중입니다."
                return
            }
            lifecycleState = .waking
            await handleDidWakeCore()
            lifecycleState = .idle

        case .screensDidSleep:
            guard lifecycleState == .idle else {
                lastActionMessage = "시스템 수면 전환 처리 중이라 화면 sleep 분석을 건너뜁니다."
                return
            }
            await analyzeNow()
        }
    }

    private func handleWillSleepCore() async {
        guard let settings = try? await settingsStore.fetchOrCreate() else {
            await captureSleepStartOnly(wasManualSleep: false)
            return
        }
        if settings.autoCleanOnWillSleep {
            await prepareForSleep(wasManualSleep: false, shouldEnterSleep: false, settings: settings)
        } else {
            let optimizationMessage = await applyBatterySleepOptimizationIfNeeded(settings: settings)
            let didCapture = await captureSleepStartOnly(wasManualSleep: false)
            if didCapture, let optimizationMessage {
                lastActionMessage = optimizationMessage
            }
        }
    }

    private func handleDidWakeCore() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            let pendingSession = try await sessionStore.fetchRecent(limit: 5).first(where: { $0.wokeAt == nil })
            guard let session = activeSession ?? pendingSession else {
                lastActionMessage = "복구할 수면 세션이 없습니다."
                await reloadHistory()
                return
            }

            if lastTerminatedRecords.isEmpty,
               let snapshot = try await snapshotStore.latest(sessionId: session.id),
               let storedTerminated = StoreJSON.decode([RunningAppRecord].self, from: snapshot.terminatedAppsJSON) {
                lastTerminatedRecords = storedTerminated
            }

            let afterBattery = batteryMonitor.currentBatteryInfo() ?? .unknown
            batteryInfo = afterBattery
            runningApps = runningAppProvider.runningApplications()
            let wokeAt = Date()
            let drain = drainCalculator.calculate(
                start: session.sleepStartedAt,
                end: wokeAt,
                batteryBefore: session.batteryBefore,
                batteryAfter: afterBattery.percent
            )
            try await sessionStore.updateAfterWake(session, wokeAt: wokeAt, batteryAfter: afterBattery.percent, drain: drain)

            let settings = try await settingsStore.fetchOrCreate()
            let restored = await restoreTerminatedApps(settings: settings)
            let pmsetLog = await logCollector.collect(
                sessionStart: session.sleepStartedAt,
                sessionEnd: wokeAt,
                includeRawExcerpt: settings.includePMSetRawExcerpt
            )
            rawLogText = pmsetLog.status.isUnavailable ? pmsetLog.status.unavailableSummaryText : pmsetLog.rawExcerpt
            parsedEvents = pmsetLog.events

            let draft = reportGenerator.generate(
                session: session,
                events: parsedEvents,
                rawPMSetExcerpt: pmsetLog.rawExcerpt,
                runningApps: runningApps.map(RunningAppRecord.init(app:)),
                terminatedApps: lastTerminatedRecords,
                restoredApps: restored,
                eventAnalysisStatus: pmsetLog.status,
                pmsetDiagnostics: pmsetLog.diagnostics
            )
            let report = try await reportStore.save(draft: draft, sessionId: session.id)
            try await snapshotStore.save(
                snapshot: AppSnapshot(
                    sessionId: session.id,
                    runningAppsJSON: StoreJSON.encode(runningApps.map(RunningAppRecord.init(app:))),
                    terminatedAppsJSON: StoreJSON.encode(lastTerminatedRecords),
                    restoredAppsJSON: StoreJSON.encode(restored)
                )
            )

            if settings.showWakeReportNotification {
                notificationService.showWakeReportNotification(report: report, session: session)
            }
            activeSession = nil
            lastActionMessage = pmsetLog.status.isUnavailable
                ? "수면 리포트를 생성했지만 pmset 로그 분석은 실패했습니다."
                : "수면 리포트를 생성했습니다."
        } catch {
            lastActionMessage = "wake 처리 실패: \(error.localizedDescription)"
        }
        await reloadHistory()
    }

    func loadPMSetLog() async {
        guard lifecycleState == .idle else {
            lastActionMessage = "전원 이벤트 처리 중이라 pmset 로그 로드를 건너뜁니다."
            return
        }
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        let pmsetLog = await logCollector.collect(sessionStart: nil, sessionEnd: nil, includeRawExcerpt: true)
        rawLogText = pmsetLog.rawExcerpt.isEmpty
            ? (pmsetLog.rawLog.isEmpty ? pmsetLog.status.unavailableSummaryText : pmsetLog.rawLog)
            : pmsetLog.rawExcerpt
        parsedEvents = pmsetLog.events
        lastActionMessage = pmsetLog.status.isUnavailable
            ? "pmset 로그 최신 tail을 불러오지 못했습니다."
            : "pmset 로그 최신 tail을 불러왔습니다."
    }

    func loadImportedLog(rawLog: String, events: [PMSetEvent], sourceName: String) {
        rawLogText = rawLog
        parsedEvents = events
        lastActionMessage = "\(sourceName) 로그를 불러왔습니다."
    }

    func reanalyzeReport(id reportId: UUID) async {
        guard lifecycleState == .idle else {
            lastActionMessage = "전원 이벤트 처리 중이라 리포트 재분석을 건너뜁니다."
            return
        }
        guard !isWorking, reanalyzingReportId == nil else { return }
        isWorking = true
        reanalyzingReportId = reportId
        defer {
            isWorking = false
            reanalyzingReportId = nil
        }

        do {
            guard let report = try await reportStore.fetch(id: reportId) else {
                lastActionMessage = "다시 분석할 리포트를 찾을 수 없습니다."
                await reloadHistory()
                return
            }
            guard let session = try await sessionStore.fetch(id: report.sessionId) else {
                lastActionMessage = "리포트의 수면 세션을 찾을 수 없습니다."
                await reloadHistory()
                return
            }
            guard let wokeAt = session.wokeAt else {
                lastActionMessage = "아직 종료되지 않은 수면 세션은 다시 분석할 수 없습니다."
                await reloadHistory()
                return
            }

            let settings = try await settingsStore.fetchOrCreate()
            let pmsetLog = await logCollector.collect(
                sessionStart: session.sleepStartedAt,
                sessionEnd: wokeAt,
                includeRawExcerpt: settings.includePMSetRawExcerpt
            )
            rawLogText = pmsetLog.status.isUnavailable ? pmsetLog.status.unavailableSummaryText : pmsetLog.rawExcerpt
            parsedEvents = pmsetLog.events

            guard !pmsetLog.status.isUnavailable else {
                _ = try await reportStore.updatePMSetDiagnostics(reportId: reportId, diagnostics: pmsetLog.diagnostics)
                lastActionMessage = "리포트 재분석 실패: 기존 수치는 유지하고 pmset 수집 진단만 갱신했습니다."
                await reloadHistory()
                return
            }

            let snapshot = await snapshotRecords(sessionId: session.id)
            let draft = reportGenerator.generate(
                session: session,
                events: pmsetLog.events,
                rawPMSetExcerpt: pmsetLog.rawExcerpt,
                runningApps: snapshot.running,
                terminatedApps: snapshot.terminated,
                restoredApps: snapshot.restored,
                eventAnalysisStatus: pmsetLog.status,
                pmsetDiagnostics: pmsetLog.diagnostics
            )
            _ = try await reportStore.update(reportId: reportId, draft: draft)
            lastActionMessage = "리포트를 다시 분석했습니다."
        } catch {
            lastActionMessage = "리포트 재분석 실패: \(error.localizedDescription)"
        }
        await reloadHistory()
    }

    func reloadHistory() async {
        recentSessions = (try? await sessionStore.fetchRecent(limit: 50)) ?? []
        recentReports = (try? await reportStore.fetchRecent(limit: 50)) ?? []
    }

    @discardableResult
    private func captureSleepStartOnly(wasManualSleep: Bool) async -> Bool {
        let battery = batteryMonitor.currentBatteryInfo() ?? .unknown
        let running = runningAppProvider.runningApplications()
        do {
            activeSession = try await sessionStore.create(startedAt: Date(), batteryBefore: battery.percent, wasManualSleep: wasManualSleep)
            lastTerminatedRecords = []
            if let session = activeSession {
                try await snapshotStore.save(
                    snapshot: AppSnapshot(
                        sessionId: session.id,
                        runningAppsJSON: StoreJSON.encode(running.map(RunningAppRecord.init(app:))),
                        terminatedAppsJSON: "[]",
                        restoredAppsJSON: "[]"
                    )
                )
            }
            return true
        } catch {
            lastActionMessage = "수면 시작 저장 실패: \(error.localizedDescription)"
            return false
        }
    }

    private func prepareForSleep(wasManualSleep: Bool, shouldEnterSleep: Bool, settings prefetchedSettings: AppSettings? = nil) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            let settings: AppSettings
            if let prefetchedSettings {
                settings = prefetchedSettings
            } else {
                settings = try await settingsStore.fetchOrCreate()
            }
            let optimizationMessage = await applyBatterySleepOptimizationIfNeeded(settings: settings)
            let battery = batteryMonitor.currentBatteryInfo() ?? .unknown
            let running = runningAppProvider.runningApplications()
            runningApps = running
            let impacts = await energyImpactProvider.impacts(for: running)
            appEnergyImpacts = impacts

            let session = try await sessionStore.create(startedAt: Date(), batteryBefore: battery.percent, wasManualSleep: wasManualSleep)
            activeSession = session

            let managed = try await managedAppStore.fetchAll()
            let candidates = terminationCandidates(
                runningApps: running,
                energyImpacts: impacts,
                managedApps: managed,
                settings: settings
            )
            let boundedCandidates = Array(candidates.prefix(settings.effectiveMaxAppsToQuitBeforeSleep))

            var terminated: [RunningAppRecord] = []
            var autoTerminatedCount = 0
            for candidate in boundedCandidates {
                let app = candidate.app
                let result = await appTerminator.terminate(
                    app: app,
                    configuration: candidate.configuration,
                    globalForceEnabled: settings.enableForceTerminate,
                    mode: .forceIfAllowed
                )
                var record = RunningAppRecord(app: app)
                record.wasTerminatedBySleepGuard = result.isTerminated
                record.terminationResultRawValue = result.rawValue
                if result.isTerminated {
                    if candidate.isAutomaticHighImpact {
                        autoTerminatedCount += 1
                    }
                    terminated.append(record)
                }
            }
            lastTerminatedRecords = terminated

            let assertions = (try? await pmsetRunner.assertions()) ?? ""
            rawLogText = assertions
            try await snapshotStore.save(
                snapshot: AppSnapshot(
                    sessionId: session.id,
                    runningAppsJSON: StoreJSON.encode(running.map(RunningAppRecord.init(app:))),
                    terminatedAppsJSON: StoreJSON.encode(terminated),
                    restoredAppsJSON: "[]"
                )
            )

            if shouldEnterSleep {
                do {
                    try await pmsetRunner.sleepNow()
                    lastActionMessage = actionMessage(
                        optimizationMessage,
                        sleepActionMessage(
                            terminatedCount: terminated.count,
                            autoTerminatedCount: autoTerminatedCount,
                            suffix: "sleepnow를 요청했습니다."
                        )
                    )
                } catch {
                    lastActionMessage = actionMessage(
                        optimizationMessage,
                        sleepActionMessage(
                            terminatedCount: terminated.count,
                            autoTerminatedCount: autoTerminatedCount,
                            suffix: "sleep 진입 실패: \(error.localizedDescription)"
                        )
                    )
                }
            } else {
                lastActionMessage = actionMessage(
                    optimizationMessage,
                    sleepActionMessage(
                        terminatedCount: terminated.count,
                        autoTerminatedCount: autoTerminatedCount,
                        suffix: "willSleep 정리 완료"
                    )
                )
            }
        } catch {
            lastActionMessage = "정리 실패: \(error.localizedDescription)"
        }
        await reloadHistory()
    }

    private func restoreTerminatedApps(settings: AppSettings) async -> [RunningAppRecord] {
        guard settings.restoreAppsOnWake else {
            return lastTerminatedRecords.map {
                var record = $0
                record.wasRestoredBySleepGuard = false
                return record
            }
        }

        let managed = (try? await managedAppStore.fetchAll()) ?? []
        let restoreMap = Dictionary(
            managed.map { ($0.bundleId, $0.shouldRestoreAfterWake) },
            uniquingKeysWith: { first, _ in first }
        )
        var restored: [RunningAppRecord] = []
        for record in lastTerminatedRecords {
            let shouldRestore = record.bundleId.flatMap { restoreMap[$0] } ?? true
            let result = await appRestorer.restore(record: record, shouldRestore: shouldRestore)
            var updated = record
            updated.wasRestoredBySleepGuard = result == .success
            restored.append(updated)
        }
        return restored
    }

    private func snapshotRecords(sessionId: UUID) async -> (
        running: [RunningAppRecord],
        terminated: [RunningAppRecord],
        restored: [RunningAppRecord]
    ) {
        guard let snapshot = try? await snapshotStore.latest(sessionId: sessionId) else {
            return ([], [], [])
        }
        return (
            StoreJSON.decode([RunningAppRecord].self, from: snapshot.runningAppsJSON) ?? [],
            StoreJSON.decode([RunningAppRecord].self, from: snapshot.terminatedAppsJSON) ?? [],
            StoreJSON.decode([RunningAppRecord].self, from: snapshot.restoredAppsJSON) ?? []
        )
    }
}

private struct TerminationCandidate {
    var app: RunningAppInfo
    var configuration: ManagedAppConfiguration
    var score: Double
    var isAutomaticHighImpact: Bool
}

private extension SleepGuardController {
    func terminationCandidates(
        runningApps: [RunningAppInfo],
        energyImpacts: [AppEnergyImpact],
        managedApps: [ManagedApp],
        settings: AppSettings
    ) -> [TerminationCandidate] {
        let scoreByProcessId = Dictionary(
            energyImpacts.map { ($0.app.processIdentifier, $0.score) },
            uniquingKeysWith: { first, _ in first }
        )
        let managedBundleIds = Set(managedApps.map(\.bundleId))
        let configByBundleId = Dictionary(
            managedApps.map { ($0.bundleId, $0.configuration) },
            uniquingKeysWith: { first, _ in first }
        )
        var candidates: [TerminationCandidate] = []

        for app in runningApps {
            guard let bundleId = app.bundleId,
                  let configuration = configByBundleId[bundleId],
                  policy.canTerminate(app, managedConfiguration: configuration) else {
                continue
            }
            candidates.append(
                TerminationCandidate(
                    app: app,
                    configuration: configuration,
                    score: scoreByProcessId[app.processIdentifier] ?? 0,
                    isAutomaticHighImpact: false
                )
            )
        }

        if settings.shouldAutoQuitHighImpactAppsBeforeSleep {
            for impact in energyImpacts where impact.level == .high {
                let app = impact.app
                guard let bundleId = app.bundleId,
                      !managedBundleIds.contains(bundleId),
                      policy.canAutoTerminateHighImpactApp(app) else {
                    continue
                }
                candidates.append(
                    TerminationCandidate(
                        app: app,
                        configuration: automaticHighImpactConfiguration(
                            app: app,
                            impact: impact,
                            timeout: settings.defaultTerminationTimeoutSeconds
                        ),
                        score: impact.score,
                        isAutomaticHighImpact: true
                    )
                )
            }
        }

        return candidates.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.app.displayName.localizedCaseInsensitiveCompare(rhs.app.displayName) == .orderedAscending
            }
            return lhs.score > rhs.score
        }
    }

    func automaticHighImpactConfiguration(
        app: RunningAppInfo,
        impact: AppEnergyImpact,
        timeout: Double
    ) -> ManagedAppConfiguration {
        ManagedAppConfiguration(
            id: UUID(),
            bundleId: app.bundleId ?? "",
            displayName: app.displayName,
            appURLString: app.bundleURL?.absoluteString ?? app.executableURL?.absoluteString,
            isEnabled: true,
            shouldQuitBeforeSleep: true,
            shouldRestoreAfterWake: true,
            allowsForceTerminate: false,
            terminationTimeoutSeconds: timeout,
            category: .unknown,
            riskLevel: impact.level
        )
    }

    func sleepActionMessage(terminatedCount: Int, autoTerminatedCount: Int, suffix: String) -> String {
        let autoText = autoTerminatedCount > 0 ? " (자동 정리 \(autoTerminatedCount)개)" : ""
        return "\(terminatedCount)개 앱을 정리했습니다\(autoText). \(suffix)"
    }

    func actionMessage(_ messages: String?...) -> String {
        messages.compactMap { message in
            guard let message, !message.isEmpty else { return nil }
            return message
        }
        .joined(separator: " ")
    }

    func applyBatterySleepOptimizationIfNeeded(settings: AppSettings) async -> String? {
        guard settings.shouldApplyBatterySleepOptimization else { return nil }

        let result = await pmsetRunner.applyBatterySleepOptimization()
        if result.isFullyApplied {
            return "배터리 수면 최적화를 적용했습니다."
        }

        let failedSettings = result.failures.map(\.setting).joined(separator: ", ")
        if result.hasPermissionFailure {
            return "배터리 수면 최적화 실패: 관리자 권한이 필요합니다. 터미널에서 sudo pmset -b tcpkeepalive 0 powernap 0 womp 0 networkoversleep 0 proximitywake 0 실행이 필요합니다. 실패 항목: \(failedSettings)"
        }
        if !result.appliedSettings.isEmpty {
            return "배터리 수면 최적화를 일부만 적용했습니다. 실패 항목: \(failedSettings)"
        }
        return "배터리 수면 최적화 실패: \(failedSettings)"
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
