import XCTest
@testable import SleepGuard

final class SystemCommandRunnerTests: XCTestCase {
    func testCapturesStandardOutput() async throws {
        let runner = SystemCommandRunner(timeoutSeconds: 2)

        let output = try await runner.run(
            executableURL: URL(fileURLWithPath: "/bin/echo"),
            arguments: ["hello"]
        )

        XCTAssertEqual(output.trimmingCharacters(in: .whitespacesAndNewlines), "hello")
    }

    func testTimesOutAndTerminatesProcess() async {
        let runner = SystemCommandRunner(timeoutSeconds: 0.1)

        do {
            _ = try await runner.run(
                executableURL: URL(fileURLWithPath: "/bin/sleep"),
                arguments: ["3"]
            )
            XCTFail("Expected timeout")
        } catch CommandError.timedOut {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
