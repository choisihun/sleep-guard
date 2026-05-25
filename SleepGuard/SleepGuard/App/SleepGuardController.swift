import Combine
import Foundation

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

    private let batteryMonitor: BatteryMonitor
    private let runningAppProvider: RunningAppProvider
    private let energyImpactProvider: AppEnergyImpactProviding
    private let policy: ProtectedAppPolicy
    private let appTerminator: AppTerminating
    private let appRestorer: AppRestoring
    private let pmsetRunner: PMSetCommandRunning
    private let logParser: PMSetLogParser
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

    init(
        batteryMonitor: BatteryMonitor,
        runningAppProvider: RunningAppProvider,
        energyImpactProvider: AppEnergyImpactProviding,
        protectedAppPolicy: ProtectedAppPolicy,
        appTerminator: AppTerminating,
        appRestorer: AppRestoring,
        pmsetRunner: PMSetCommandRunning,
        logParser: PMSetLogParser,
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

    func refreshCurrentState() async {
        batteryInfo = batteryMonitor.currentBatteryInfo() ?? .unknown
        runningApps = runningAppProvider.runningApplications()
        let managed = (try? await managedAppStore.fetchAll()) ?? []
        appEnergyImpacts = await energyImpactProvider.impacts(for: runningApps)
        suspiciousApps = suspiciousAppDetector.suspiciousApps(runningApps: runningApps, managedApps: managed)
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

    func analyzeNow() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        await refreshCurrentState()
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
        await prepareForSleep(wasManualSleep: true, shouldEnterSleep: true)
    }

    func handleWillSleep() async {
        let settings = (try? await settingsStore.fetchOrCreate()) ?? AppSettings()
        if settings.autoCleanOnWillSleep {
            await prepareForSleep(wasManualSleep: false, shouldEnterSleep: false)
        } else {
            await captureSleepStartOnly(wasManualSleep: false)
        }
    }

    func handleDidWake() async {
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
            let rawLog = (try? await pmsetRunner.log()) ?? ""
            let excerpt = settings.includePMSetRawExcerpt ? logParser.excerpt(rawLog, around: session.sleepStartedAt, end: wokeAt) : ""
            rawLogText = excerpt
            parsedEvents = logParser.parse(excerpt.isEmpty ? rawLog : excerpt)

            let draft = reportGenerator.generate(
                session: session,
                events: parsedEvents,
                rawPMSetExcerpt: excerpt,
                runningApps: runningApps.map(RunningAppRecord.init(app:)),
                terminatedApps: lastTerminatedRecords,
                restoredApps: restored
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
            lastActionMessage = "수면 리포트를 생성했습니다."
        } catch {
            lastActionMessage = "wake 처리 실패: \(error.localizedDescription)"
        }
        await reloadHistory()
    }

    func loadPMSetLog() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let raw = try await pmsetRunner.log()
            rawLogText = raw
            parsedEvents = logParser.parse(raw)
            lastActionMessage = "pmset 로그를 불러왔습니다."
        } catch {
            rawLogText = error.localizedDescription
            parsedEvents = []
        }
    }

    func loadImportedLog(rawLog: String, events: [PMSetEvent], sourceName: String) {
        rawLogText = rawLog
        parsedEvents = events
        lastActionMessage = "\(sourceName) 로그를 불러왔습니다."
    }

    func reloadHistory() async {
        recentSessions = (try? await sessionStore.fetchRecent(limit: 50)) ?? []
        recentReports = (try? await reportStore.fetchRecent(limit: 50)) ?? []
    }

    private func captureSleepStartOnly(wasManualSleep: Bool) async {
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
        } catch {
            lastActionMessage = "수면 시작 저장 실패: \(error.localizedDescription)"
        }
    }

    private func prepareForSleep(wasManualSleep: Bool, shouldEnterSleep: Bool) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            let settings = try await settingsStore.fetchOrCreate()
            let battery = batteryMonitor.currentBatteryInfo() ?? .unknown
            let running = runningAppProvider.runningApplications()
            runningApps = running
            let impacts = await energyImpactProvider.impacts(for: running)
            appEnergyImpacts = impacts
            let scoreByProcessId = Dictionary(
                impacts.map { ($0.app.processIdentifier, $0.score) },
                uniquingKeysWith: { first, _ in first }
            )

            let session = try await sessionStore.create(startedAt: Date(), batteryBefore: battery.percent, wasManualSleep: wasManualSleep)
            activeSession = session

            let managed = try await managedAppStore.fetchAll()
            let configByBundleId = Dictionary(
                managed.map { ($0.bundleId, $0.configuration) },
                uniquingKeysWith: { first, _ in first }
            )
            let candidates = running.filter { app in
                guard let bundleId = app.bundleId else { return false }
                return policy.canTerminate(app, managedConfiguration: configByBundleId[bundleId])
            }
            let sortedCandidates = candidates.sorted { lhs, rhs in
                let lhsScore = scoreByProcessId[lhs.processIdentifier] ?? 0
                let rhsScore = scoreByProcessId[rhs.processIdentifier] ?? 0
                if lhsScore == rhsScore {
                    return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                }
                return lhsScore > rhsScore
            }
            let boundedCandidates = Array(sortedCandidates.prefix(settings.effectiveMaxAppsToQuitBeforeSleep))

            var terminated: [RunningAppRecord] = []
            for app in boundedCandidates {
                guard let bundleId = app.bundleId else { continue }
                let result = await appTerminator.terminate(
                    app: app,
                    configuration: configByBundleId[bundleId],
                    globalForceEnabled: settings.enableForceTerminate,
                    mode: .forceIfAllowed
                )
                var record = RunningAppRecord(app: app)
                record.wasTerminatedBySleepGuard = result.isTerminated
                record.terminationResultRawValue = result.rawValue
                if result.isTerminated {
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
                    lastActionMessage = "\(terminated.count)개 앱을 정리하고 sleepnow를 요청했습니다."
                } catch {
                    lastActionMessage = "\(terminated.count)개 앱은 정리했지만 sleep 진입 실패: \(error.localizedDescription)"
                }
            } else {
                lastActionMessage = "willSleep 정리 완료: \(terminated.count)개 앱 종료 요청"
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
            let shouldRestore = record.bundleId.flatMap { restoreMap[$0] } ?? false
            let result = await appRestorer.restore(record: record, shouldRestore: shouldRestore)
            var updated = record
            updated.wasRestoredBySleepGuard = result == .success
            restored.append(updated)
        }
        return restored
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
