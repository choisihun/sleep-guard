import Foundation

nonisolated protocol CommandRunning {
    func run(executableURL: URL, arguments: [String]) async throws -> String
    func run(
        executableURL: URL,
        arguments: [String],
        collectedOutputLimit: Int?,
        stdoutHandler: (@Sendable (Data) -> Void)?
    ) async throws -> String
}

nonisolated enum CommandError: Error, LocalizedError, Equatable {
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

extension CommandRunning {
    func run(
        executableURL: URL,
        arguments: [String],
        collectedOutputLimit: Int?,
        stdoutHandler: (@Sendable (Data) -> Void)?
    ) async throws -> String {
        let output = try await run(executableURL: executableURL, arguments: arguments)
        if let data = output.data(using: .utf8) {
            stdoutHandler?(data)
            guard let collectedOutputLimit else { return output }
            guard collectedOutputLimit > 0 else { return "" }
            return String(data: data.suffix(collectedOutputLimit), encoding: .utf8) ?? ""
        }
        return output
    }
}
