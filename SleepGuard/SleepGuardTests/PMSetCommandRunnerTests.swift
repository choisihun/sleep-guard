import Foundation
import XCTest
@testable import SleepGuard

final class PMSetCommandRunnerTests: XCTestCase {
    @MainActor
    func testPMSetRunnerUsesMockRunner() async throws {
        let mock = MockCommandRunner()
        let runner = PMSetCommandRunner(runner: mock)

        let assertions = try await runner.assertions()
        let log = try await runner.log()
        try await runner.sleepNow()

        XCTAssertEqual(assertions, "mock output for -g assertions")
        XCTAssertEqual(log, "mock output for -g log")
        XCTAssertEqual(mock.commands.last?.1, ["sleepnow"])
    }

    @MainActor
    func testPMSetRunnerLetsCollectorFilterBoundedDateRange() async throws {
        let mock = MockCommandRunner()
        let runner = PMSetCommandRunner(runner: mock)
        let start = try XCTUnwrap(Self.date("2026-05-27 03:00:00 +0900"))
        let end = try XCTUnwrap(Self.date("2026-05-27 12:30:00 +0900"))

        try await runner.streamLog(from: start, to: end) { _ in }

        XCTAssertEqual(mock.commands.last?.1, ["-g", "log"])
    }

    @MainActor
    func testBatterySleepOptimizationDisablesWakeSettingsOnBatteryProfile() async {
        let mock = MockCommandRunner()
        let runner = PMSetCommandRunner(runner: mock)

        let result = await runner.applyBatterySleepOptimization()

        XCTAssertTrue(result.isFullyApplied)
        XCTAssertEqual(
            mock.commands.map(\.1),
            [
                ["-b", "tcpkeepalive", "0"],
                ["-b", "powernap", "0"],
                ["-b", "womp", "0"],
                ["-b", "networkoversleep", "0"],
                ["-b", "proximitywake", "0"]
            ]
        )
    }

    private static func date(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter.date(from: string)
    }
}

private final class MockCommandRunner: CommandRunning {
    private(set) var commands: [(URL, [String])] = []

    func run(executableURL: URL, arguments: [String]) async throws -> String {
        commands.append((executableURL, arguments))
        return "mock output for \(arguments.joined(separator: " "))"
    }
}
