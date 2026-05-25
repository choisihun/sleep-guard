import Testing
@testable import SleepGuard

struct PMSetAssertionParserTests {
    @Test func extractsAssertionTypeAndProcess() {
        let parsed = PMSetAssertionParser().parse(
            line: #"PID 322(coreaudiod) PreventUserIdleSystemSleep named: "com.apple.audio.Music playback""#
        )

        #expect(parsed.assertionType == "PreventUserIdleSystemSleep")
        #expect(parsed.processName == "coreaudiod")
    }
}
