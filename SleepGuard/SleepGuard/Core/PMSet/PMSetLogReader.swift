import Foundation

nonisolated protocol PMSetLogReading {
    func rawLog() async throws -> String
    func rawAssertions() async throws -> String
}

nonisolated struct PMSetLogReader: PMSetLogReading {
    var commandRunner: PMSetCommandRunning

    init(commandRunner: PMSetCommandRunning = PMSetCommandRunner()) {
        self.commandRunner = commandRunner
    }

    func rawLog() async throws -> String {
        try await commandRunner.log()
    }

    func rawAssertions() async throws -> String {
        try await commandRunner.assertions()
    }
}
