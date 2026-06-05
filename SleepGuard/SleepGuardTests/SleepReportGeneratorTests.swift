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

    @Test func recommendsCheckingUSBCDevicesWhenWakeSignalsRepeat() {
        let rawLog = """
        2026-05-22 23:15:12 +0900 DarkWake              DarkWake from Normal Sleep [CDN] : due to USB-C_plug Using BATT (Charge:72%)
        2026-05-22 23:17:20 +0900 kernel                Port-USB-C driver is slow to respond
        """
        let events = PMSetLogParser().parse(rawLog)
        let session = SleepSession(
            sleepStartedAt: Date(timeIntervalSince1970: 0),
            wokeAt: Date(timeIntervalSince1970: 3600),
            batteryBefore: 73,
            batteryAfter: 68,
            drainPercent: 5,
            drainPerHour: 5,
            durationSeconds: 3600,
            wasManualSleep: true
        )

        let draft = SleepReportGenerator().generate(
            session: session,
            events: events,
            rawPMSetExcerpt: rawLog,
            runningApps: [],
            terminatedApps: [],
            restoredApps: []
        )

        #expect(draft.summaryText.contains("USB-C/외부 장치"))
        #expect(draft.summaryText.contains("전체 감소량"))
        #expect(draft.recommendations.contains { $0.contains("USB-C/외부 장치") })
    }

    @Test func ignoresReleasedAssertionNoiseWhenScoringReport() {
        let released = (0..<20)
            .map { index in
                "2026-05-31 23:23:\(String(format: "%02d", index)) +0900 Assertions           PID 440(coreaudiod) Released PreventUserIdleSystemSleep \"com.apple.audio.context\(index).preventuseridlesleep\" 01:12:36 id:0x0x10000\(index)"
            }
        let turnedOff = (20..<40)
            .map { index in
                "2026-05-31 23:23:\(String(format: "%02d", index)) +0900 Assertions           PID 440(coreaudiod) TurnedOff PreventUserIdleSystemSleep \"com.apple.audio.context\(index).preventuseridlesleep\" 00:01:00 id:0x0x10000\(index)"
            }
        let darkWakeAssertions = (40..<50)
            .map { index in
                "2026-05-31 23:23:\(String(format: "%02d", index - 40)) +0900 Assertions           PID 688(corespeechd) Created PreventSystemSleep \"com.apple.corespeech.darkwake.powerassertion\" 00:00:00 id:0x0x70000\(index)"
            }
        let rawLog = (released + turnedOff + darkWakeAssertions).joined(separator: "\n")
        let events = PMSetLogParser().parse(rawLog)
        let session = SleepSession(
            sleepStartedAt: Date(timeIntervalSince1970: 0),
            wokeAt: Date(timeIntervalSince1970: 3600),
            batteryBefore: 60,
            batteryAfter: 60,
            drainPercent: 0,
            drainPerHour: 0,
            durationSeconds: 3600,
            wasManualSleep: false
        )

        let draft = SleepReportGenerator().generate(
            session: session,
            events: events,
            rawPMSetExcerpt: rawLog,
            runningApps: [],
            terminatedApps: [],
            restoredApps: []
        )

        #expect(events.filter { $0.category == .assertion }.count == 50)
        #expect(draft.assertionCount == 0)
        #expect(draft.riskLevel == .good)
        #expect(!draft.topSuspectNames.contains("coreaudiod"))
        #expect(!draft.topSuspectNames.contains("corespeechd"))
        #expect(!draft.recommendations.contains { $0.contains("assertion") })
    }

    @Test func treatsLongSleepNinePercentDrainAsCautionWhenEventsUnavailable() {
        let session = SleepSession(
            sleepStartedAt: Date(timeIntervalSince1970: 0),
            wokeAt: Date(timeIntervalSince1970: 12.6 * 3600),
            batteryBefore: 79,
            batteryAfter: 70,
            drainPercent: 9,
            drainPerHour: 0.71,
            durationSeconds: 12.6 * 3600,
            wasManualSleep: false
        )

        let draft = SleepReportGenerator().generate(
            session: session,
            events: [],
            rawPMSetExcerpt: "",
            runningApps: [],
            terminatedApps: [],
            restoredApps: [],
            eventAnalysisStatus: .unavailable
        )

        #expect(draft.riskLevel == .caution)
        #expect(draft.summaryText.contains("장시간 수면 기준"))
        #expect(!draft.summaryText.contains("안정적으로 보입니다"))
        #expect(draft.recommendations.contains { $0.contains("배터리 수면 최적화") })
    }

    @Test func explainsNetworkKeepAliveAsDominantCauseWhenUSBCIsSecondary() {
        let repeatedLog = (0..<24)
            .map { index in
                """
                2026-06-04 01:00:00 +0900 Sleep                Entering Sleep state due to 'Maintenance Sleep':TCPKeepAlive=active Using Batt (Charge:64%) sample=\(index)
                2026-06-04 01:00:02 +0900 Wake Requests        [*process=dasd request=SleepService deltaSecs=931] [process=mDNSResponder request=Maintenance deltaSecs=7198] [process=powerd request=TCPKATurnOff deltaSecs=316858] sample=\(index)
                2026-06-04 01:10:00 +0900 DarkWake             DarkWake from Deep Idle [CDNP] : due to NUB.SPMISw3IRQ nub-spmi0.0x02 rtc/SleepService Using BATT (Charge:63%) 2 secs sample=\(index)
                2026-06-04 01:10:00 +0900 Kernel Client Acks   Delays to Wake notifications: [Port-USB-C driver is slow(msg: SetState to 1)(51 ms)] sample=\(index)
                """
            }
            .joined(separator: "\n")
        let events = PMSetLogParser().parse(repeatedLog)
        let session = SleepSession(
            sleepStartedAt: Date(timeIntervalSince1970: 0),
            wokeAt: Date(timeIntervalSince1970: 44 * 3600),
            batteryBefore: 64,
            batteryAfter: 54,
            drainPercent: 10,
            drainPerHour: 0.23,
            durationSeconds: 44 * 3600,
            wasManualSleep: false
        )

        let draft = SleepReportGenerator().generate(
            session: session,
            events: events,
            rawPMSetExcerpt: repeatedLog,
            runningApps: [],
            terminatedApps: [],
            restoredApps: []
        )

        #expect(draft.summaryText.contains("가장 큰 반복 원인은 네트워크 유지/TCP KeepAlive"))
        #expect(draft.summaryText.contains("반복 요청자는 dasd, mDNSResponder, powerd"))
        #expect(draft.summaryText.contains("USB-C 신호는 반복 wake 때 같이 잡힌 지연 신호"))
    }

    @Test func explainsLargeTotalDrainWithoutCallingUnavailableAnalysisStable() {
        let session = SleepSession(
            sleepStartedAt: Date(timeIntervalSince1970: 0),
            wokeAt: Date(timeIntervalSince1970: 25 * 3600),
            batteryBefore: 93,
            batteryAfter: 77,
            drainPercent: 16,
            drainPerHour: 0.63,
            durationSeconds: 25 * 3600,
            wasManualSleep: true
        )

        let draft = SleepReportGenerator().generate(
            session: session,
            events: [],
            rawPMSetExcerpt: "",
            runningApps: [],
            terminatedApps: [],
            restoredApps: [],
            eventAnalysisStatus: .unavailable
        )

        #expect(draft.riskLevel == .caution)
        #expect(draft.summaryText.contains("총 감소량이 커"))
        #expect(!draft.summaryText.contains("안정적으로 보입니다"))
        #expect(draft.recommendations.contains { $0.contains("총 배터리 감소량") })
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
