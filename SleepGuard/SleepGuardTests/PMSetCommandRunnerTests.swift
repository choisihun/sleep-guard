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
}

private final class MockCommandRunner: CommandRunning {
    private(set) var commands: [(URL, [String])] = []

    func run(executableURL: URL, arguments: [String]) async throws -> String {
        commands.append((executableURL, arguments))
        return "mock output for \(arguments.joined(separator: " "))"
    }
}
