import Foundation

protocol CommandRunning {
    func run(executableURL: URL, arguments: [String]) async throws -> String
}

enum CommandError: Error, LocalizedError, Equatable {
    case executableNotFound(URL)
    case nonZeroExitCode(Int32, String)
    case timedOut
    case emptyOutput
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let url): "Executable not found: \(url.path)"
        case .nonZeroExitCode(let code, let stderr): "Command failed with exit code \(code): \(stderr)"
        case .timedOut: "Command timed out"
        case .emptyOutput: "Command returned empty output"
        case .unknown(let message): message
        }
    }
}
