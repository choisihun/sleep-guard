import Testing
@testable import SleepGuard

struct PMSetWakeRequestParserTests {
    @Test func extractsWakeRequestProcesses() {
        let line = #"Wake Requests [*process=dasd request=SleepService deltaSecs=1019 wakeAt=2026-05-22 09:02:59 info="com.apple.dasd:501:task"] [process=mDNSResponder request=MaintenanceWake] [process=PowerUIAgent request=UserWake]"#
        let parser = PMSetWakeRequestParser()
        let names = parser.processNames(in: line)
        let requests = parser.requests(in: line)

        #expect(names.contains("dasd"))
        #expect(names.contains("mDNSResponder"))
        #expect(names.contains("PowerUIAgent"))
        #expect(!names.contains("SleepService"))
        #expect(requests.first?.requestName == "SleepService")
        #expect(requests.first?.deltaSeconds == 1019)
        #expect(requests.first?.wakeAtText == "2026-05-22 09:02:59")
        #expect(requests.first?.info == "com.apple.dasd:501:task")
    }
}
