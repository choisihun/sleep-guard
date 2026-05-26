import Foundation

nonisolated protocol PMSetCommandRunning {
    func assertions() async throws -> String
    func log() async throws -> String
    func streamLog(_ lineHandler: @escaping @Sendable (String) -> Void) async throws
    func sched() async throws -> String
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
}

nonisolated struct PMSetCommandRunner: PMSetCommandRunning {
    private let runner: CommandRunning
    private let executableURL = URL(fileURLWithPath: "/usr/bin/pmset")

    init(runner: CommandRunning = SystemCommandRunner()) {
        self.runner = runner
    }

    func assertions() async throws -> String {
        try await runner.run(executableURL: executableURL, arguments: ["-g", "assertions"])
    }

    func log() async throws -> String {
        try await runner.run(executableURL: executableURL, arguments: ["-g", "log"])
    }

    func streamLog(_ lineHandler: @escaping @Sendable (String) -> Void) async throws {
        let splitter = CommandLineSplitter(lineHandler: lineHandler)
        _ = try await runner.run(
            executableURL: executableURL,
            arguments: ["-g", "log"],
            collectedOutputLimit: 0,
            stdoutHandler: { data in
                splitter.append(data)
            }
        )
        splitter.finish()
    }

    func sched() async throws -> String {
        try await runner.run(executableURL: executableURL, arguments: ["-g", "sched"])
    }

    func sleepNow() async throws {
        _ = try await runner.run(executableURL: executableURL, arguments: ["sleepnow"])
    }
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
