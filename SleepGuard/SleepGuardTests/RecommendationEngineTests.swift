import Testing
@testable import SleepGuard

struct RecommendationEngineTests {
    @Test func emitsExpectedRecommendations() {
        let recommendations = RecommendationEngine().recommendations(
            drainPerHour: 2,
            darkWakeCount: 25,
            tcpKeepAliveCount: 1,
            bluetoothDelayCount: 7,
            assertionProcesses: ["coreaudiod"],
            runningProcessNames: ["Docker Desktop", "Simulator"]
        )

        #expect(recommendations.contains { $0.contains("시간당 배터리") })
        #expect(recommendations.contains { $0.contains("짧은 깨움") })
        #expect(recommendations.contains { $0.contains("네트워크") })
        #expect(recommendations.contains { $0.contains("Bluetooth") })
        #expect(recommendations.contains { $0.contains("assertion") })
        #expect(recommendations.contains { $0.contains("배터리 영향 상위") })
    }
}
