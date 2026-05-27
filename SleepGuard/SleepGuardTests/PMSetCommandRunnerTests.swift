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
    func testPMSetRunnerStreamsLogForBoundedDateRange() async throws {
        let mock = MockCommandRunner()
        let runner = PMSetCommandRunner(runner: mock)
        let start = try XCTUnwrap(Self.date("2026-05-27 03:00:00 +0900"))
        let end = try XCTUnwrap(Self.date("2026-05-27 12:30:00 +0900"))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        try await runner.streamLog(from: start, to: end) { _ in }

        XCTAssertEqual(
            mock.commands.last?.1,
            ["-g", "log", "-start", formatter.string(from: start), "-end", formatter.string(from: end)]
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
