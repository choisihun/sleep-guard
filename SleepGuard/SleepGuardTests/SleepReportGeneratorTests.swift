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
            restoredApps: []
        )

        #expect(events.filter { $0.category == .wakeRequest }.count > 1)
        #expect(draft.wakeRequestCount == 1)
        #expect(draft.topSuspectNames.contains("dasd"))
        #expect(draft.topSuspectNames.contains("mDNSResponder"))
    }
}
