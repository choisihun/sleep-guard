import AppKit
import Foundation
import Testing
@testable import SleepGuard

struct AppEnergyImpactProviderTests {
    @Test func parsesProcessResourceSnapshots() {
        let output = """
          101   1   2.5  512000
          202   1   0.0  128000
        """

        let snapshots = ProcessResourceSnapshot.parse(psOutput: output)

        #expect(snapshots[101]?.parentProcessId == 1)
        #expect(snapshots[101]?.cpuPercent == 2.5)
        #expect(snapshots[101]?.residentMemoryKB == 512000)
        #expect(snapshots[202]?.cpuPercent == 0)
    }

    @Test func aggregatesChildProcessesIntoOwningAppImpact() async {
        let appPID: pid_t = 500
        let rendererPID: pid_t = 501
        let workerPID: pid_t = 502
        let unrelatedPID: pid_t = 600
        let runner = EnergyImpactCommandRunner(
            output: """
              \(appPID) 1 0.2 100000
              \(rendererPID) \(appPID) 10.0 250000
              \(workerPID) \(rendererPID) 2.0 50000
              \(unrelatedPID) 1 80.0 999999
            """
        )
        let provider = SystemAppEnergyImpactProvider(runner: runner, scoring: Self.scoring)
        let codex = RunningAppInfo(
            bundleId: "com.openai.codex",
            displayName: "Codex",
            executableURL: nil,
            bundleURL: URL(fileURLWithPath: "/Applications/Codex.app"),
            processIdentifier: appPID,
            activationPolicyRawValue: NSApplication.ActivationPolicy.regular.rawValue,
            isTerminated: false,
            isHidden: false
        )

        let impacts = await provider.impacts(for: [codex])

        #expect(impacts.first?.cpuPercent == 12.2)
        #expect(impacts.first?.memoryMB == 400000.0 / 1024.0)
        #expect(impacts.first?.level == .high)
    }

    @Test func excludesCurrentAppFromEnergyImpacts() async {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let rendererPID: pid_t = 4242
        let runner = EnergyImpactCommandRunner(
            output: """
              \(currentPID) 1 99.0 512000
              \(rendererPID) 1 2.0 256000
            """
        )
        let provider = SystemAppEnergyImpactProvider(runner: runner, scoring: Self.scoring)
        let currentApp = RunningAppInfo(
            bundleId: Bundle.main.bundleIdentifier ?? "com.sihun.sleepguard.tests",
            displayName: "Sleep Guard",
            executableURL: nil,
            bundleURL: nil,
            processIdentifier: currentPID,
            activationPolicyRawValue: NSApplication.ActivationPolicy.regular.rawValue,
            isTerminated: false,
            isHidden: false
        )
        let renderer = RunningAppInfo(
            bundleId: "com.example.Renderer",
            displayName: "Renderer",
            executableURL: nil,
            bundleURL: nil,
            processIdentifier: rendererPID,
            activationPolicyRawValue: NSApplication.ActivationPolicy.regular.rawValue,
            isTerminated: false,
            isHidden: false
        )

        let impacts = await provider.impacts(for: [currentApp, renderer])

        #expect(impacts.map(\.app.bundleId) == ["com.example.Renderer"])
    }

    private static let scoring = AppEnergyImpactScoring(
        highRiskScoreMinimum: 45,
        mediumRiskScoreMinimum: 18,
        cpuScoreMultiplier: 16,
        maximumCPUScore: 80,
        memoryMegabytesPerPoint: 120,
        maximumMemoryScore: 14,
        foregroundScore: 6,
        visibleScore: 2,
        maximumScore: 100,
        minimumIncludedScore: 0,
        cpuReasonMinimum: 1,
        memoryReasonMinimumMegabytes: 500
    )
}

private final class EnergyImpactCommandRunner: CommandRunning {
    let output: String

    init(output: String) {
        self.output = output
    }

    func run(executableURL: URL, arguments: [String]) async throws -> String {
        output
    }
}
