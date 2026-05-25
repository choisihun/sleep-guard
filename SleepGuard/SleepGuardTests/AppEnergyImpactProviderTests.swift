import Testing
@testable import SleepGuard

struct AppEnergyImpactProviderTests {
    @Test func parsesProcessResourceSnapshots() {
        let output = """
          101   2.5  512000
          202   0.0  128000
        """

        let snapshots = ProcessResourceSnapshot.parse(psOutput: output)

        #expect(snapshots[101]?.cpuPercent == 2.5)
        #expect(snapshots[101]?.residentMemoryKB == 512000)
        #expect(snapshots[202]?.cpuPercent == 0)
    }
}
