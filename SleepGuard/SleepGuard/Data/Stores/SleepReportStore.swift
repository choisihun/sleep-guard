import Foundation
import SwiftData

@MainActor
protocol SleepReportStoring {
    func save(draft: SleepReportDraft, sessionId: UUID) async throws -> SleepReport
    func update(reportId: UUID, draft: SleepReportDraft) async throws -> SleepReport
    func updatePMSetDiagnostics(reportId: UUID, diagnostics: PMSetLogDiagnostics) async throws -> SleepReport
    func fetchRecent(limit: Int) async throws -> [SleepReport]
    func fetch(id: UUID) async throws -> SleepReport?
    func fetch(sessionId: UUID) async throws -> SleepReport?
}

enum SleepReportStoreError: Error, LocalizedError {
    case reportNotFound

    var errorDescription: String? {
        switch self {
        case .reportNotFound: "Sleep report not found."
        }
    }
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
            topSuspectNames: draft.topSuspectNames,
            eventAnalysisStatusRawValue: draft.eventAnalysisStatus.rawValue,
            pmsetDiagnostics: draft.pmsetDiagnostics
        )
        context.insert(report)
        try context.save()
        return report
    }

    func update(reportId: UUID, draft: SleepReportDraft) async throws -> SleepReport {
        guard let report = try await fetch(id: reportId) else {
            throw SleepReportStoreError.reportNotFound
        }
        apply(draft: draft, to: report)
        try context.save()
        return report
    }

    func updatePMSetDiagnostics(reportId: UUID, diagnostics: PMSetLogDiagnostics) async throws -> SleepReport {
        guard let report = try await fetch(id: reportId) else {
            throw SleepReportStoreError.reportNotFound
        }
        report.apply(pmsetDiagnostics: diagnostics)
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

    private func apply(draft: SleepReportDraft, to report: SleepReport) {
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
    }
}
