import Foundation
import Testing
@testable import SleepGuard

struct PMSetLogCollectorTests {
    @Test func retriesAfterCommandFailureAndReturnsMatchedSessionEvents() async throws {
        let runner = StubPMSetRunner(logResults: [
            .failure(CommandError.timedOut),
            .success(Self.sampleLog)
        ])
        let collector = PMSetLogCollector(commandRunner: runner, retryDelays: [0, 0], paddingSeconds: 0)
        let start = try #require(Self.date("2026-05-22 23:10:00 +0900"))
        let end = try #require(Self.date("2026-05-22 23:19:00 +0900"))

        let collection = await collector.collect(sessionStart: start, sessionEnd: end, includeRawExcerpt: true)

        #expect(collection.status == .available)
        #expect(collection.diagnostics.retryCount == 1)
        #expect(collection.diagnostics.sessionEventLineCount == 4)
        #expect(collection.diagnostics.rawLogLineCount == 4)
        #expect(collection.rawExcerpt.contains("TCPKeepAlive=active"))
        #expect(collection.events.contains { $0.category == .darkWake })
        #expect(collection.events.contains { $0.category == .wakeRequest && $0.processName == "dasd" })
        #expect(collection.events.contains { $0.category == .bluetooth })
        let hasTCPKeepAlive = collection.events.contains { $0.isTCPKeepAliveActive }
        #expect(hasTCPKeepAlive)
    }

    @Test func retriesAfterEmptyOutputAndTracksRetryCount() async throws {
        let runner = StubPMSetRunner(logResults: [
            .success("   \n"),
            .success(Self.sampleLog)
        ])
        let collector = PMSetLogCollector(commandRunner: runner, retryDelays: [0, 0], paddingSeconds: 0)
        let start = try #require(Self.date("2026-05-22 23:10:00 +0900"))
        let end = try #require(Self.date("2026-05-22 23:19:00 +0900"))

        let collection = await collector.collect(sessionStart: start, sessionEnd: end, includeRawExcerpt: false)

        #expect(collection.status == .available)
        #expect(collection.diagnostics.retryCount == 1)
        #expect(collection.rawExcerpt.isEmpty)
        #expect(collection.events.contains { $0.category == .darkWake })
    }

    @Test func returnsUnavailableWhenNoEventsMatchSessionWindow() async throws {
        let runner = StubPMSetRunner(logResults: [
            .success("""
            2026-05-22 20:00:00 +0900 DarkWake              DarkWake from Normal Sleep [CDN] : due to old.event Using BATT (Charge:80%)
            """)
        ])
        let collector = PMSetLogCollector(commandRunner: runner, retryDelays: [0], paddingSeconds: 0)
        let start = try #require(Self.date("2026-05-22 23:10:00 +0900"))
        let end = try #require(Self.date("2026-05-22 23:19:00 +0900"))

        let collection = await collector.collect(sessionStart: start, sessionEnd: end, includeRawExcerpt: true)

        #expect(collection.status == .unavailable)
        #expect(collection.events.isEmpty)
        #expect(collection.diagnostics.sessionEventLineCount == 0)
        #expect(collection.diagnostics.rawLogLineCount == 1)
        #expect(collection.diagnostics.errorDescription?.contains("No pmset events matched") == true)
    }

    @Test func returnsUnavailableWhenEveryAttemptFails() async throws {
        let runner = StubPMSetRunner(logResults: [
            .failure(CommandError.timedOut),
            .failure(CommandError.emptyOutput)
        ])
        let collector = PMSetLogCollector(commandRunner: runner, retryDelays: [0, 0], paddingSeconds: 0)
        let start = try #require(Self.date("2026-05-22 23:10:00 +0900"))
        let end = try #require(Self.date("2026-05-22 23:19:00 +0900"))

        let collection = await collector.collect(sessionStart: start, sessionEnd: end, includeRawExcerpt: true)

        #expect(collection.status == .unavailable)
        #expect(collection.diagnostics.retryCount == 1)
        #expect(collection.diagnostics.rawLogLineCount == 0)
        #expect(collection.diagnostics.errorDescription?.isEmpty == false)
    }

    @Test func keepsMatchedEventsCollectedBeforeCommandTimeout() async throws {
        let runner = TimeoutAfterLinesPMSetRunner(lines: Self.sampleLog.split(separator: "\n").map(String.init))
        let collector = PMSetLogCollector(commandRunner: runner, retryDelays: [0], paddingSeconds: 0)
        let start = try #require(Self.date("2026-05-22 23:10:00 +0900"))
        let end = try #require(Self.date("2026-05-22 23:19:00 +0900"))

        let collection = await collector.collect(sessionStart: start, sessionEnd: end, includeRawExcerpt: true)

        #expect(collection.status == .available)
        #expect(collection.events.contains { $0.category == .darkWake })
        #expect(collection.events.contains { $0.category == .wakeRequest && $0.processName == "dasd" })
        #expect(collection.diagnostics.rawLogLineCount == 4)
        #expect(collection.diagnostics.errorDescription?.contains("Command timed out") == true)
    }

    @Test func capsManualTailWithoutKeepingFullPMSetLog() async throws {
        let rawLog = (0..<10)
            .map { index in
                "2026-05-22 23:1\(index):00 +0900 Sleep                 Entering Sleep state due to 'Maintenance Sleep' Using Batt (Charge:73%)"
            }
            .joined(separator: "\n")
        let runner = StubPMSetRunner(logResults: [.success(rawLog)])
        let collector = PMSetLogCollector(
            commandRunner: runner,
            retryDelays: [0],
            paddingSeconds: 0,
            maxRawExcerptLines: 5,
            maxManualTailLines: 3
        )

        let collection = await collector.collect(sessionStart: nil, sessionEnd: nil, includeRawExcerpt: true)

        #expect(collection.status == .available)
        #expect(collection.diagnostics.rawLogLineCount == 10)
        #expect(collection.rawExcerpt.split(separator: "\n").count == 3)
        #expect(!collection.rawExcerpt.contains("23:10:00"))
        #expect(collection.rawExcerpt.contains("23:19:00"))
    }

    @Test func capsSessionRawExcerptButKeepsAllWindowEvents() async throws {
        let rawLog = (0..<5)
            .map { index in
                "2026-05-22 23:1\(index):00 +0900 DarkWake              DarkWake from Normal Sleep [CDN] : due to event.\(index) Using BATT (Charge:72%)"
            }
            .joined(separator: "\n")
        let runner = StubPMSetRunner(logResults: [.success(rawLog)])
        let collector = PMSetLogCollector(
            commandRunner: runner,
            retryDelays: [0],
            paddingSeconds: 0,
            maxRawExcerptLines: 2,
            maxManualTailLines: 3
        )
        let start = try #require(Self.date("2026-05-22 23:10:00 +0900"))
        let end = try #require(Self.date("2026-05-22 23:14:00 +0900"))

        let collection = await collector.collect(sessionStart: start, sessionEnd: end, includeRawExcerpt: true)

        #expect(collection.status == .available)
        #expect(collection.events.filter { $0.category == .darkWake }.count == 5)
        #expect(collection.rawExcerpt.split(separator: "\n").count == 2)
        #expect(collection.diagnostics.sessionEventLineCount == 5)
    }

    @Test func streamsOnlySessionAnalysisWindowWhenSessionDatesAreAvailable() async throws {
        let runner = StubPMSetRunner(logResults: [.success(Self.sampleLog)])
        let collector = PMSetLogCollector(commandRunner: runner, retryDelays: [0], paddingSeconds: 600)
        let start = try #require(Self.date("2026-05-22 23:10:00 +0900"))
        let end = try #require(Self.date("2026-05-22 23:19:00 +0900"))

        _ = await collector.collect(sessionStart: start, sessionEnd: end, includeRawExcerpt: true)

        #expect(runner.rangedStreamRequests.count == 1)
        #expect(runner.rangedStreamRequests.first?.start == start.addingTimeInterval(-600))
        #expect(runner.rangedStreamRequests.first?.end == end.addingTimeInterval(600))
    }

    private static func date(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter.date(from: string)
    }

    private static let sampleLog = """
    2026-05-22 23:10:01 +0900 Sleep                 Entering Sleep state due to 'Maintenance Sleep':TCPKeepAlive=active Using Batt (Charge:73%)
    2026-05-22 23:15:12 +0900 DarkWake              DarkWake from Normal Sleep [CDN] : due to EC.DarkPME/MaintenanceWake Using BATT (Charge:72%)
    2026-05-22 23:15:13 +0900 Wake Requests         [*process=dasd request=SleepService deltaSecs=120] [process=mDNSResponder request=MaintenanceWake]
    2026-05-22 23:17:00 +0900 bluetoothd            bluetooth.sleep is slow
    """
}

private final class StubPMSetRunner: PMSetCommandRunning {
    private var logResults: [Result<String, Error>]
    private(set) var rangedStreamRequests: [(start: Date?, end: Date?)] = []

    init(logResults: [Result<String, Error>]) {
        self.logResults = logResults
    }

    func assertions() async throws -> String {
        ""
    }

    func log() async throws -> String {
        guard !logResults.isEmpty else {
            throw CommandError.emptyOutput
        }
        return try logResults.removeFirst().get()
    }

    func streamLog(_ lineHandler: @escaping @Sendable (String) -> Void) async throws {
        let rawLog = try await log()
        rawLog
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .forEach(lineHandler)
    }

    func streamLog(from start: Date?, to end: Date?, _ lineHandler: @escaping @Sendable (String) -> Void) async throws {
        rangedStreamRequests.append((start, end))
        try await streamLog(lineHandler)
    }

    func sched() async throws -> String {
        ""
    }

    func sleepNow() async throws {}
}

private final class TimeoutAfterLinesPMSetRunner: PMSetCommandRunning {
    private let lines: [String]

    init(lines: [String]) {
        self.lines = lines
    }

    func assertions() async throws -> String {
        ""
    }

    func log() async throws -> String {
        ""
    }

    func streamLog(_ lineHandler: @escaping @Sendable (String) -> Void) async throws {
        for line in lines {
            lineHandler(line)
        }
        throw CommandError.timedOut
    }

    func streamLog(from start: Date?, to end: Date?, _ lineHandler: @escaping @Sendable (String) -> Void) async throws {
        try await streamLog(lineHandler)
    }

    func sched() async throws -> String {
        ""
    }

    func sleepNow() async throws {}
}
