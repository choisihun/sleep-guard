import Foundation

struct SystemCommandRunner: CommandRunning {
    var timeoutSeconds: TimeInterval = 20

    func run(executableURL: URL, arguments: [String]) async throws -> String {
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw CommandError.executableNotFound(executableURL)
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while process.isRunning {
            if Date() >= deadline {
                process.terminate()
                throw CommandError.timedOut
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw CommandError.nonZeroExitCode(process.terminationStatus, stderr)
        }
        return output
    }
}
