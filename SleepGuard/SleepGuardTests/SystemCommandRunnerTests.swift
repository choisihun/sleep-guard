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

    func testDrainsLargeStandardOutputAndErrorWhileProcessRuns() async throws {
        let runner = SystemCommandRunner(timeoutSeconds: 5)
        let script = """
        i=0
        while [ $i -lt 8000 ]; do
          printf 'stdout-line-%05d abcdefghijklmnopqrstuvwxyz\\n' "$i"
          printf 'stderr-line-%05d abcdefghijklmnopqrstuvwxyz\\n' "$i" 1>&2
          i=$((i + 1))
        done
        """

        let output = try await runner.run(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", script]
        )

        XCTAssertTrue(output.contains("stdout-line-00000"))
        XCTAssertTrue(output.contains("stdout-line-07999"))
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
