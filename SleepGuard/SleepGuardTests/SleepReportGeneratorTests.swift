import Foundation
import Testing
@testable import SleepGuard

struct SleepReportGeneratorTests {
    @Test func countsWakeRequestLinesWithoutProcessFanout() {
        let rawLog = """
        2026-05-22 23:15:13 +0900 Wake Requests         [*process=dasd request=SleepService] [process=mDNSResponder request=MaintenanceWake] [process=powerd request=UserWake]
        """
        let events = PMSetLogParser().parse(rawLog)
        let session = SleepSession(
            sleepStartedAt: Date(timeIntervalSince1970: 0),
            wokeAt: Date(timeIntervalSince1970: 3600),
            batteryBefore: 73,
            batteryAfter: 70,
            drainPercent: 3,
            drainPerHour: 3,
            durationSeconds: 3600,
            wasManualSleep: true
        )

        let draft = SleepReportGenerator().generate(
            session: session,
            events: events,
            rawPMSetExcerpt: rawLog,
            runningApps: [],
            terminatedApps: [],
            restoredApps: [],
            pmsetDiagnostics: PMSetLogDiagnostics(
                collectedAt: Date(timeIntervalSince1970: 10),
                retryCount: 1,
                sessionEventLineCount: 1,
                analysisWindowStart: session.sleepStartedAt,
                analysisWindowEnd: session.wokeAt,
                rawLogLineCount: 1
            )
        )

        #expect(events.filter { $0.category == .wakeRequest }.count > 1)
        #expect(draft.wakeRequestCount == 1)
        #expect(draft.topSuspectNames.contains("dasd"))
        #expect(draft.topSuspectNames.contains("mDNSResponder"))
        #expect(draft.pmsetDiagnostics?.retryCount == 1)
    }

    @Test func marksEventAnalysisUnavailableWhenPMSetLogCannotBeRead() {
        let rawLog = """
        2026-05-22 23:15:12 +0900 DarkWake              DarkWake from Normal Sleep [CDN] : due to EC.DarkPME/MaintenanceWake Using BATT (Charge:72%)
        2026-05-22 23:17:00 +0900 bluetoothd            bluetooth sleep is slow
        """
        let events = PMSetLogParser().parse(rawLog)
        let session = SleepSession(
            sleepStartedAt: Date(timeIntervalSince1970: 0),
            wokeAt: Date(timeIntervalSince1970: 3600),
            batteryBefore: 73,
            batteryAfter: 70,
            drainPercent: 3,
            drainPerHour: 3,
            durationSeconds: 3600,
            wasManualSleep: true
        )

        let draft = SleepReportGenerator().generate(
            session: session,
            events: events,
            rawPMSetExcerpt: "",
            runningApps: [],
            terminatedApps: [],
            restoredApps: [],
            eventAnalysisStatus: .unavailable
        )

        #expect(draft.eventAnalysisStatus == .unavailable)
        #expect(draft.darkWakeCount == 0)
        #expect(draft.bluetoothDelayCount == 0)
        #expect(draft.summaryText.contains("이벤트는 분석하지 못했습니다"))
        #expect(draft.recommendations.contains { $0.contains("이벤트 분석이 제한") })
    }

    @Test func warnsForLegacyHighDrainReportsWithoutTrackedEventAnalysisStatus() {
        let report = SleepReport(
            sessionId: UUID(),
            riskScore: 40,
            riskLevelRawValue: SleepRiskLevel.caution.rawValue,
            summaryText: "배터리는 22%에서 17%로 5% 감소했습니다.",
            recommendationTexts: [],
            darkWakeCount: 0,
            wakeRequestCount: 0,
            assertionCount: 0,
            bluetoothDelayCount: 0,
            tcpKeepAliveCount: 0,
            rawPMSetExcerpt: "",
            topSuspectNames: [],
            eventAnalysisStatusRawValue: nil
        )

        #expect(report.eventAnalysisWarningText?.contains("수집 성공 여부") == true)
    }
}
