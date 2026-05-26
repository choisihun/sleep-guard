import Foundation
import SwiftData

enum SleepEventAnalysisStatus: String, Codable, CaseIterable {
    case available
    case unavailable

    var isUnavailable: Bool {
        self == .unavailable
    }

    var unavailableSummaryText: String {
        "pmset 로그를 불러오거나 세션 시간대와 매칭하지 못해 DarkWake, Wake Request, Bluetooth, TCP KeepAlive 이벤트는 분석하지 못했습니다."
    }

    var unavailableRecommendationText: String {
        "pmset 로그를 불러오거나 세션 시간대와 매칭하지 못해 이벤트 분석이 제한되었습니다. 배터리 감소가 크면 시스템 로그를 별도로 확인하세요."
    }
}

@Model
final class SleepReport {
    var id: UUID
    var sessionId: UUID
    var generatedAt: Date
    var riskScore: Int
    var riskLevelRawValue: String
    var summaryText: String
    var recommendationTextsJSON: String
    var darkWakeCount: Int
    var wakeRequestCount: Int
    var assertionCount: Int
    var bluetoothDelayCount: Int
    var tcpKeepAliveCount: Int
    var rawPMSetExcerpt: String
    var topSuspectNamesJSON: String
    var eventAnalysisStatusRawValue: String?
    var pmsetLogCollectedAt: Date?
    var pmsetLogRetryCount: Int?
    var pmsetSessionEventLineCount: Int?
    var pmsetAnalysisWindowStart: Date?
    var pmsetAnalysisWindowEnd: Date?
    var pmsetRawLogLineCount: Int?
    var pmsetLogCollectionError: String?

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        generatedAt: Date = Date(),
        riskScore: Int,
        riskLevelRawValue: String,
        summaryText: String,
        recommendationTexts: [String],
        darkWakeCount: Int,
        wakeRequestCount: Int,
        assertionCount: Int,
        bluetoothDelayCount: Int,
        tcpKeepAliveCount: Int,
        rawPMSetExcerpt: String,
        topSuspectNames: [String],
        eventAnalysisStatusRawValue: String? = SleepEventAnalysisStatus.available.rawValue,
        pmsetDiagnostics: PMSetLogDiagnostics? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.generatedAt = generatedAt
        self.riskScore = riskScore
        self.riskLevelRawValue = riskLevelRawValue
        self.summaryText = summaryText
        self.recommendationTextsJSON = StoreJSON.encode(recommendationTexts)
        self.darkWakeCount = darkWakeCount
        self.wakeRequestCount = wakeRequestCount
        self.assertionCount = assertionCount
        self.bluetoothDelayCount = bluetoothDelayCount
        self.tcpKeepAliveCount = tcpKeepAliveCount
        self.rawPMSetExcerpt = rawPMSetExcerpt
        self.topSuspectNamesJSON = StoreJSON.encode(topSuspectNames)
        self.eventAnalysisStatusRawValue = eventAnalysisStatusRawValue
        self.pmsetLogCollectedAt = nil
        self.pmsetLogRetryCount = nil
        self.pmsetSessionEventLineCount = nil
        self.pmsetAnalysisWindowStart = nil
        self.pmsetAnalysisWindowEnd = nil
        self.pmsetRawLogLineCount = nil
        self.pmsetLogCollectionError = nil
        apply(pmsetDiagnostics: pmsetDiagnostics)
    }

    var riskLevel: SleepRiskLevel {
        SleepRiskLevel(rawValue: riskLevelRawValue) ?? .good
    }

    var eventAnalysisStatus: SleepEventAnalysisStatus {
        get {
            SleepEventAnalysisStatus(rawValue: eventAnalysisStatusRawValue ?? SleepEventAnalysisStatus.available.rawValue) ?? .available
        }
        set {
            eventAnalysisStatusRawValue = newValue.rawValue
        }
    }

    var eventAnalysisWarningText: String? {
        if eventAnalysisStatus.isUnavailable {
            return eventAnalysisStatus.unavailableSummaryText
        }
        if eventAnalysisStatusRawValue == nil,
           rawPMSetExcerpt.isEmpty,
           darkWakeCount == 0,
           wakeRequestCount == 0,
           assertionCount == 0,
           bluetoothDelayCount == 0,
           tcpKeepAliveCount == 0,
           riskLevel != .good {
            return "이전 버전 리포트라 pmset 로그 수집 성공 여부를 확인할 수 없습니다. 이벤트 수치가 0이어도 실제 수면 이벤트가 없었다고 단정하지 마세요."
        }
        return nil
    }

    var recommendationTexts: [String] {
        get { StoreJSON.decode([String].self, from: recommendationTextsJSON) ?? [] }
        set { recommendationTextsJSON = StoreJSON.encode(newValue) }
    }

    var topSuspectNames: [String] {
        get { StoreJSON.decode([String].self, from: topSuspectNamesJSON) ?? [] }
        set { topSuspectNamesJSON = StoreJSON.encode(newValue) }
    }

    var hasPMSetDiagnostics: Bool {
        pmsetLogCollectedAt != nil ||
            pmsetLogRetryCount != nil ||
            pmsetSessionEventLineCount != nil ||
            pmsetAnalysisWindowStart != nil ||
            pmsetAnalysisWindowEnd != nil ||
            pmsetRawLogLineCount != nil ||
            pmsetLogCollectionError != nil
    }

    var pmsetDiagnostics: PMSetLogDiagnostics? {
        guard hasPMSetDiagnostics else { return nil }
        return PMSetLogDiagnostics(
            collectedAt: pmsetLogCollectedAt,
            retryCount: pmsetLogRetryCount ?? 0,
            sessionEventLineCount: pmsetSessionEventLineCount ?? 0,
            analysisWindowStart: pmsetAnalysisWindowStart,
            analysisWindowEnd: pmsetAnalysisWindowEnd,
            rawLogLineCount: pmsetRawLogLineCount ?? 0,
            errorDescription: pmsetLogCollectionError
        )
    }

    func apply(pmsetDiagnostics diagnostics: PMSetLogDiagnostics?) {
        pmsetLogCollectedAt = diagnostics?.collectedAt
        pmsetLogRetryCount = diagnostics?.retryCount
        pmsetSessionEventLineCount = diagnostics?.sessionEventLineCount
        pmsetAnalysisWindowStart = diagnostics?.analysisWindowStart
        pmsetAnalysisWindowEnd = diagnostics?.analysisWindowEnd
        pmsetRawLogLineCount = diagnostics?.rawLogLineCount
        pmsetLogCollectionError = diagnostics?.errorDescription
    }
}
