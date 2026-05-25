import Foundation

protocol PMSetCommandRunning {
    func assertions() async throws -> String
    func log() async throws -> String
    func sched() async throws -> String
    func sleepNow() async throws
}

struct PMSetCommandRunner: PMSetCommandRunning {
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

    func sched() async throws -> String {
        try await runner.run(executableURL: executableURL, arguments: ["-g", "sched"])
    }

    func sleepNow() async throws {
        _ = try await runner.run(executableURL: executableURL, arguments: ["sleepnow"])
    }
}
