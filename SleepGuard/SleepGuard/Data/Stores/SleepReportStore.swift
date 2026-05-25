import Foundation
import SwiftData

@MainActor
protocol SleepReportStoring {
    func save(draft: SleepReportDraft, sessionId: UUID) async throws -> SleepReport
    func fetchRecent(limit: Int) async throws -> [SleepReport]
    func fetch(id: UUID) async throws -> SleepReport?
    func fetch(sessionId: UUID) async throws -> SleepReport?
}

@MainActor
final class SwiftDataSleepReportStore: SleepReportStoring {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

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
            topSuspectNames: draft.topSuspectNames
        )
        context.insert(report)
        try context.save()
        return report
    }

    func fetchRecent(limit: Int = 20) async throws -> [SleepReport] {
        var descriptor = FetchDescriptor<SleepReport>(sortBy: [SortDescriptor(\.generatedAt, order: .reverse)])
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func fetch(id: UUID) async throws -> SleepReport? {
        let descriptor = FetchDescriptor<SleepReport>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }

    func fetch(sessionId: UUID) async throws -> SleepReport? {
        let descriptor = FetchDescriptor<SleepReport>(predicate: #Predicate { $0.sessionId == sessionId })
        return try context.fetch(descriptor).first
    }
}
