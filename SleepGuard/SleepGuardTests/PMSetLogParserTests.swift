import Foundation
import Testing
@testable import SleepGuard

struct PMSetLogParserTests {
    @Test func parsesSampleLogSignals() {
        let events = PMSetLogParser().parse(Self.sample)

        #expect(events.contains { $0.category == .sleep && $0.batteryCharge == 73 && $0.isTCPKeepAliveActive })
        #expect(events.filter { $0.category == .darkWake }.count == 1)
        #expect(events.contains { $0.category == .darkWake && $0.wakeReason == "EC.DarkPME/MaintenanceWake" })
        #expect(events.contains { $0.category == .wakeRequest && $0.processName == "dasd" })
        #expect(events.contains { $0.category == .wakeRequest && $0.processName == "dasd" && $0.wakeReason == "SleepService" })
        #expect(events.contains { $0.category == .wakeRequest && $0.message.contains("Wake Requests") })
        #expect(events.filter { $0.category == .wakeRequest }.count == 2)
        #expect(!events.contains { $0.category == .wakeRequest && $0.processName == nil })
        #expect(events.contains { $0.category == .assertion && $0.processName == "coreaudiod" && $0.assertionType == "PreventUserIdleSystemSleep" })
        #expect(events.contains { $0.category == .assertion && $0.processName == "powerd" && $0.assertionType == "InternalPreventSleep" })
        #expect(events.contains { $0.category == .assertion && $0.batteryCharge == 72 })
        #expect(events.contains { $0.category == .bluetooth })
        #expect(events.contains { $0.category == .usbC })
        #expect(events.contains { $0.category == .sleepService })
    }

    @Test func filtersEventsToSleepSessionWindow() throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        let start = try #require(formatter.date(from: "2026-05-22 23:10:00 +0900"))
        let end = try #require(formatter.date(from: "2026-05-22 23:18:30 +0900"))
        let rawLog = """
        2026-05-22 20:00:00 +0900 DarkWake              DarkWake from Normal Sleep [CDN] : due to old.event Using BATT (Charge:80%)
        \(Self.sample)
        2026-05-23 02:00:00 +0900 DarkWake              DarkWake from Normal Sleep [CDN] : due to future.event Using BATT (Charge:65%)
        """

        let events = PMSetLogParser().events(rawLog, around: start, end: end)

        #expect(events.contains { $0.wakeReason == "EC.DarkPME/MaintenanceWake" })
        #expect(!events.contains { $0.rawLine.contains("old.event") })
        #expect(!events.contains { $0.rawLine.contains("future.event") })
    }

    @Test func doesNotTreatDarkwakeAssertionTextAsDarkWakeEvent() {
        let rawLog = """
        2026-05-26 05:29:10 +0900 Assertions           PID 445(powerd) Created InternalPreventSleep "Holding in darkwake for up to 20 seconds to query model for inactivity prediction" 00:00:00 id:0x0xd00009859 [System: SRPrevSleep kCPU]
        """

        let events = PMSetLogParser().parse(rawLog)

        #expect(events.contains { $0.category == .assertion && $0.assertionType == "InternalPreventSleep" })
        #expect(!events.contains { $0.category == .darkWake })
    }

    private static let sample = """
    2026-05-22 23:10:01 +0900 Sleep                 Entering Sleep state due to 'Maintenance Sleep':TCPKeepAlive=active Using Batt (Charge:73%)
    2026-05-22 23:15:12 +0900 DarkWake              DarkWake from Normal Sleep [CDN] : due to EC.DarkPME/MaintenanceWake Using BATT (Charge:72%)
    2026-05-22 23:15:13 +0900 Wake Requests         [*process=dasd request=SleepService deltaSecs=120] [process=mDNSResponder request=MaintenanceWake]
    2026-05-22 23:16:02 +0900 Assertions            PID 322(coreaudiod) PreventUserIdleSystemSleep named: "com.apple.audio.Music playback"
    2026-05-22 23:16:44 +0900 Assertions            Summary- [System: PrevIdle DeclUser PushSrvc SRPrevSleep kCPU kDisp] Using Batt(Charge: 72)
    2026-05-22 23:16:45 +0900 Assertions            PID 445(powerd) Created InternalPreventSleep "PM configd - Wait for Device enumeration" 00:00:00 id:0x0xd00009be9
    2026-05-22 23:17:00 +0900 bluetoothd            bluetooth sleep is slow
    2026-05-22 23:17:20 +0900 kernel                Port-USB-C driver is slow to respond
    2026-05-22 23:18:00 +0900 SleepService          com.apple.sleepservices.sessionStarted
    """
}
