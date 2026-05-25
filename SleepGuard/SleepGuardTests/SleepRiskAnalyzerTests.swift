import Testing
@testable import SleepGuard

struct SleepRiskAnalyzerTests {
    @Test func marksHighDrainAndDarkWakeAsBad() {
        let result = SleepRiskAnalyzer().analyze(
            SleepRiskInput(
                drainPercent: 12,
                drainPerHour: 3.2,
                darkWakeCount: 24,
                wakeRequestCount: 8,
                assertionCount: 2,
                bluetoothDelayCount: 6,
                tcpKeepAliveCount: 1,
                suspiciousProcessNames: ["Docker Desktop"]
            )
        )

        #expect(result.level == .bad)
        #expect(result.score >= 70)
    }

    @Test func keepsQuietSleepGood() {
        let result = SleepRiskAnalyzer().analyze(
            SleepRiskInput(
                drainPercent: 1,
                drainPerHour: 0.2,
                darkWakeCount: 0,
                wakeRequestCount: 0,
                assertionCount: 0,
                bluetoothDelayCount: 0,
                tcpKeepAliveCount: 0,
                suspiciousProcessNames: []
            )
        )

        #expect(result.level == .good)
    }
}
