import Testing
@testable import SleepGuard

struct RecommendationEngineTests {
    @Test func emitsExpectedRecommendations() {
        let recommendations = RecommendationEngine().recommendations(
            drainPercent: 6,
            drainPerHour: 2,
            darkWakeCount: 25,
            tcpKeepAliveCount: 1,
            bluetoothDelayCount: 7,
            usbCWakeCount: 2,
            assertionProcesses: ["coreaudiod"],
            runningProcessNames: ["Docker Desktop", "Simulator"]
        )

        #expect(recommendations.contains { $0.contains("시간당 배터리") })
        #expect(recommendations.contains { $0.contains("짧은 깨움") })
        #expect(recommendations.contains { $0.contains("네트워크") })
        #expect(recommendations.contains { $0.contains("Bluetooth") })
        #expect(recommendations.contains { $0.contains("USB-C") })
        #expect(recommendations.contains { $0.contains("assertion") })
        #expect(recommendations.contains { $0.contains("배터리 영향 상위") })
    }

    @Test func flagsLargeTotalDrainEvenWhenHourlyAverageIsLow() {
        let recommendations = RecommendationEngine().recommendations(
            drainPercent: 16,
            drainPerHour: 0.63,
            darkWakeCount: 0,
            tcpKeepAliveCount: 0,
            bluetoothDelayCount: 0,
            assertionProcesses: [],
            runningProcessNames: []
        )

        #expect(recommendations.contains { $0.contains("총 배터리 감소량") })
    }

    @Test func recommendsBatterySleepOptimizationForLongSleepDrain() {
        let recommendations = RecommendationEngine().recommendations(
            drainPercent: 9,
            drainPerHour: 0.71,
            durationSeconds: 12.6 * 3600,
            darkWakeCount: 0,
            tcpKeepAliveCount: 1,
            bluetoothDelayCount: 0,
            assertionProcesses: [],
            runningProcessNames: []
        )

        #expect(recommendations.contains { $0.contains("장시간 수면") })
        #expect(recommendations.contains { $0.contains("배터리 수면 최적화") })
    }
}
