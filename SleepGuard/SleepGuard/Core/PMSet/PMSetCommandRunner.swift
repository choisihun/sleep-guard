import Foundation

nonisolated struct PMSetBatterySleepOptimizationResult: Equatable, Sendable {
    struct Failure: Equatable, Sendable {
        var setting: String
        var reason: String
    }

    var appliedSettings: [String]
    var failures: [Failure]

    var isFullyApplied: Bool {
        failures.isEmpty
    }

    var hasPermissionFailure: Bool {
        failures.contains { failure in
            let reason = failure.reason.lowercased()
            return reason.contains("privilege")
                || reason.contains("permission")
                || reason.contains("root")
                || reason.contains("not permitted")
        }
    }
}

nonisolated protocol PMSetCommandRunning {
    func assertions() async throws -> String
    func log() async throws -> String
    func streamLog(_ lineHandler: @escaping @Sendable (String) -> Void) async throws
    func streamLog(from start: Date?, to end: Date?, _ lineHandler: @escaping @Sendable (String) -> Void) async throws
    func sched() async throws -> String
    func applyBatterySleepOptimization() async -> PMSetBatterySleepOptimizationResult
    func sleepNow() async throws
}

extension PMSetCommandRunning {
    func streamLog(_ lineHandler: @escaping @Sendable (String) -> Void) async throws {
        let rawLog = try await log()
        rawLog
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .forEach(lineHandler)
    }

    func streamLog(from start: Date?, to end: Date?, _ lineHandler: @escaping @Sendable (String) -> Void) async throws {
        try await streamLog(lineHandler)
    }

    func applyBatterySleepOptimization() async -> PMSetBatterySleepOptimizationResult {
        PMSetBatterySleepOptimizationResult(appliedSettings: [], failures: [])
    }
}

nonisolated struct PMSetCommandRunner: PMSetCommandRunning {
    private let runner: CommandRunning
    private let executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    private let shellURL = URL(fileURLWithPath: "/bin/sh")

    init(runner: CommandRunning = SystemCommandRunner(timeoutSeconds: 60)) {
        self.runner = runner
    }

    func assertions() async throws -> String {
        try await runner.run(executableURL: executableURL, arguments: ["-g", "assertions"])
    }

    func log() async throws -> String {
        try await runner.run(executableURL: executableURL, arguments: ["-g", "log"])
    }

    func streamLog(_ lineHandler: @escaping @Sendable (String) -> Void) async throws {
        try await streamLog(arguments: ["-g", "log"], lineHandler)
    }

    func streamLog(from start: Date?, to end: Date?, _ lineHandler: @escaping @Sendable (String) -> Void) async throws {
        guard let start, let end else {
            try await streamLog(lineHandler)
            return
        }

        try await streamLog(
            executableURL: shellURL,
            arguments: ["-c", boundedLogScript(start: start, end: end)],
            lineHandler
        )
    }

    private func streamLog(arguments: [String], _ lineHandler: @escaping @Sendable (String) -> Void) async throws {
        try await streamLog(executableURL: executableURL, arguments: arguments, lineHandler)
    }

    private func streamLog(
        executableURL: URL,
        arguments: [String],
        _ lineHandler: @escaping @Sendable (String) -> Void
    ) async throws {
        let splitter = CommandLineSplitter(lineHandler: lineHandler)
        _ = try await runner.run(
            executableURL: executableURL,
            arguments: arguments,
            collectedOutputLimit: 0,
            stdoutHandler: { data in
                splitter.append(data)
            }
        )
        splitter.finish()
    }

    private func boundedLogScript(start: Date, end: Date) -> String {
        let startText = logTimestampText(start)
        let endText = logTimestampText(end)
        return """
        /usr/bin/pmset -g log | /usr/bin/awk -v start="\(startText)" -v end="\(endText)" '
        /^[0-9][0-9][0-9][0-9]-/ {
            timestamp = substr($0, 1, 19)
            if (timestamp >= start && timestamp <= end) {
                print
            } else if (timestamp > end) {
                exit
            }
        }'
        """
    }

    private func logTimestampText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    func sched() async throws -> String {
        try await runner.run(executableURL: executableURL, arguments: ["-g", "sched"])
    }

    func applyBatterySleepOptimization() async -> PMSetBatterySleepOptimizationResult {
        var appliedSettings: [String] = []
        var failures: [PMSetBatterySleepOptimizationResult.Failure] = []

        for setting in PMSetBatterySleepSetting.allCases {
            do {
                _ = try await runner.run(
                    executableURL: executableURL,
                    arguments: ["-b", setting.rawValue, setting.disabledValue]
                )
                appliedSettings.append(setting.rawValue)
            } catch {
                failures.append(
                    PMSetBatterySleepOptimizationResult.Failure(
                        setting: setting.rawValue,
                        reason: error.localizedDescription
                    )
                )
            }
        }

        return PMSetBatterySleepOptimizationResult(appliedSettings: appliedSettings, failures: failures)
    }

    func sleepNow() async throws {
        _ = try await runner.run(executableURL: executableURL, arguments: ["sleepnow"])
    }
}

nonisolated private enum PMSetBatterySleepSetting: String, CaseIterable {
    case tcpkeepalive
    case powernap
    case womp
    case networkoversleep
    case proximitywake

    var disabledValue: String { "0" }
}

nonisolated private final class CommandLineSplitter: @unchecked Sendable {
    private let lock = NSLock()
    private let lineHandler: @Sendable (String) -> Void
    private var pending = Data()

    init(lineHandler: @escaping @Sendable (String) -> Void) {
        self.lineHandler = lineHandler
    }

    func append(_ data: Data) {
        lock.lock()
        pending.append(data)

        while let newlineIndex = pending.firstIndex(of: 0x0A) {
            let lineData = pending[..<newlineIndex]
            pending.removeSubrange(...newlineIndex)
            emit(lineData)
        }
        lock.unlock()
    }

    func finish() {
        lock.lock()
        guard !pending.isEmpty else {
            lock.unlock()
            return
        }
        let lineData = pending
        pending.removeAll(keepingCapacity: false)
        emit(lineData)
        lock.unlock()
    }

    private func emit(_ data: Data.SubSequence) {
        let line = String(data: Data(data), encoding: .utf8) ?? ""
        lineHandler(line)
    }
}
