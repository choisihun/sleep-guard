import Foundation
import SwiftData

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
        topSuspectNames: [String]
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
    }

    var riskLevel: SleepRiskLevel {
        SleepRiskLevel(rawValue: riskLevelRawValue) ?? .good
    }

    var recommendationTexts: [String] {
        get { StoreJSON.decode([String].self, from: recommendationTextsJSON) ?? [] }
        set { recommendationTextsJSON = StoreJSON.encode(newValue) }
    }

    var topSuspectNames: [String] {
        get { StoreJSON.decode([String].self, from: topSuspectNamesJSON) ?? [] }
        set { topSuspectNamesJSON = StoreJSON.encode(newValue) }
    }
}
