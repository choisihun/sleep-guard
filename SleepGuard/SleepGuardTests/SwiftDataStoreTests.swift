import XCTest
@testable import SleepGuard

@MainActor
final class SwiftDataStoreTests: XCTestCase {
    func testProtocolStoresCreateUpdateAndFetchSessionReportAndSnapshot() async throws {
        let sessionStore = InMemorySleepSessionStore()
        let reportStore = InMemorySleepReportStore()
        let snapshotStore = InMemoryAppSnapshotStore()
        let startedAt = Date(timeIntervalSince1970: 100)
        let wokeAt = Date(timeIntervalSince1970: 3_700)

        let session = try await sessionStore.create(startedAt: startedAt, batteryBefore: 80, wasManualSleep: true)
        try await sessionStore.updateAfterWake(
            session,
            wokeAt: wokeAt,
            batteryAfter: 74,
            drain: BatteryDrainResult(drainPercent: 6, durationSeconds: 3_600, drainPerHour: 6)
        )

        let draft = SleepReportDraft(
            riskScore: 20,
            riskLevel: .caution,
            summaryText: "summary",
            recommendations: ["recommendation"],
            darkWakeCount: 1,
            wakeRequestCount: 2,
            assertionCount: 3,
            bluetoothDelayCount: 4,
            tcpKeepAliveCount: 5,
            rawPMSetExcerpt: "excerpt",
            topSuspectNames: ["dasd"],
            eventAnalysisStatus: .available,
            pmsetDiagnostics: PMSetLogDiagnostics(rawLogLineCount: 10)
        )
        let report = try await reportStore.save(draft: draft, sessionId: session.id)
        try await snapshotStore.save(
            snapshot: AppSnapshot(
                sessionId: session.id,
                runningAppsJSON: "[1]",
                terminatedAppsJSON: "[2]",
                restoredAppsJSON: "[3]"
            )
        )

        let fetchedSession = try await sessionStore.fetch(id: session.id)
        let recentSession = try await sessionStore.fetchRecent(limit: 1).first
        let fetchedReport = try await reportStore.fetch(id: report.id)
        let sessionReport = try await reportStore.fetch(sessionId: session.id)
        let recentReport = try await reportStore.fetchRecent(limit: 1).first
        let latestSnapshot = try await snapshotStore.latest(sessionId: session.id)

        XCTAssertEqual(fetchedSession?.batteryAfter, 74)
        XCTAssertEqual(recentSession?.id, session.id)
        XCTAssertEqual(fetchedReport?.wakeRequestCount, 2)
        XCTAssertEqual(sessionReport?.id, report.id)
        XCTAssertEqual(recentReport?.id, report.id)
        XCTAssertEqual(latestSnapshot?.terminatedAppsJSON, "[2]")
    }
}

@MainActor
private final class InMemorySleepSessionStore: SleepSessionStoring {
    private var sessions: [SleepSession] = []

    func create(startedAt: Date, batteryBefore: Int, wasManualSleep: Bool) async throws -> SleepSession {
        let session = SleepSession(
            sleepStartedAt: startedAt,
            batteryBefore: batteryBefore,
            wasManualSleep: wasManualSleep
        )
        sessions.append(session)
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
        Array(sessions.sorted { $0.sleepStartedAt > $1.sleepStartedAt }.prefix(limit))
    }

    func fetch(id: UUID) async throws -> SleepSession? {
        sessions.first { $0.id == id }
    }
}

@MainActor
private final class InMemorySleepReportStore: SleepReportStoring {
    private var reports: [SleepReport] = []

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
        reports.append(report)
        return report
    }

    func update(reportId: UUID, draft: SleepReportDraft) async throws -> SleepReport {
        guard let report = try await fetch(id: reportId) else {
            throw SleepReportStoreError.reportNotFound
        }
        report.riskScore = draft.riskScore
        report.riskLevelRawValue = draft.riskLevel.rawValue
        report.summaryText = draft.summaryText
        report.recommendationTexts = draft.recommendations
        report.darkWakeCount = draft.darkWakeCount
        report.wakeRequestCount = draft.wakeRequestCount
        report.assertionCount = draft.assertionCount
        report.bluetoothDelayCount = draft.bluetoothDelayCount
        report.tcpKeepAliveCount = draft.tcpKeepAliveCount
        report.rawPMSetExcerpt = draft.rawPMSetExcerpt
        report.topSuspectNames = draft.topSuspectNames
        report.eventAnalysisStatus = draft.eventAnalysisStatus
        report.apply(pmsetDiagnostics: draft.pmsetDiagnostics)
        return report
    }

    func updatePMSetDiagnostics(reportId: UUID, diagnostics: PMSetLogDiagnostics) async throws -> SleepReport {
        guard let report = try await fetch(id: reportId) else {
            throw SleepReportStoreError.reportNotFound
        }
        report.apply(pmsetDiagnostics: diagnostics)
        return report
    }

    func fetchRecent(limit: Int) async throws -> [SleepReport] {
        Array(reports.sorted { $0.generatedAt > $1.generatedAt }.prefix(limit))
    }

    func fetch(id: UUID) async throws -> SleepReport? {
        reports.first { $0.id == id }
    }

    func fetch(sessionId: UUID) async throws -> SleepReport? {
        reports.first { $0.sessionId == sessionId }
    }
}

@MainActor
private final class InMemoryAppSnapshotStore: AppSnapshotStoring {
    private var snapshots: [AppSnapshot] = []

    func save(snapshot: AppSnapshot) async throws {
        snapshots.append(snapshot)
    }

    func latest(sessionId: UUID) async throws -> AppSnapshot? {
        snapshots
            .filter { $0.sessionId == sessionId }
            .sorted { $0.capturedAt > $1.capturedAt }
            .first
    }
}
