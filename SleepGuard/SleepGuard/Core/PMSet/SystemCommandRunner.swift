import Foundation

nonisolated struct SystemCommandRunner: CommandRunning {
    var timeoutSeconds: TimeInterval = 20

    func run(executableURL: URL, arguments: [String]) async throws -> String {
        try await run(
            executableURL: executableURL,
            arguments: arguments,
            collectedOutputLimit: nil,
            stdoutHandler: nil
        )
    }

    func run(
        executableURL: URL,
        arguments: [String],
        collectedOutputLimit: Int?,
        stdoutHandler: (@Sendable (Data) -> Void)?
    ) async throws -> String {
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

        let outputBuffer = CommandOutputBuffer(maxBytes: collectedOutputLimit)
        let errorBuffer = CommandOutputBuffer(maxBytes: 1_048_576)
        let stdoutDrain = PipeDrain(buffer: outputBuffer, dataHandler: stdoutHandler)
        let stderrDrain = PipeDrain(buffer: errorBuffer)
        stdoutDrain.start(reading: outputPipe.fileHandleForReading)
        stderrDrain.start(reading: errorPipe.fileHandleForReading)

        do {
            try process.run()
        } catch {
            stdoutDrain.stop()
            stderrDrain.stop()
            throw error
        }

        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while process.isRunning {
            if Date() >= deadline {
                process.terminate()
                stdoutDrain.stop()
                stderrDrain.stop()
                throw CommandError.timedOut
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        try? await Task.sleep(nanoseconds: 50_000_000)
        stdoutDrain.stop()
        stderrDrain.stop()
        let output = outputBuffer.stringValue
        let stderr = errorBuffer.stringValue

        guard process.terminationStatus == 0 else {
            throw CommandError.nonZeroExitCode(process.terminationStatus, stderr)
        }
        return output
    }
}

nonisolated private final class PipeDrain: @unchecked Sendable {
    private let buffer: CommandOutputBuffer
    private let dataHandler: (@Sendable (Data) -> Void)?
    private weak var fileHandle: FileHandle?

    init(buffer: CommandOutputBuffer, dataHandler: (@Sendable (Data) -> Void)? = nil) {
        self.buffer = buffer
        self.dataHandler = dataHandler
    }

    func start(reading fileHandle: FileHandle) {
        self.fileHandle = fileHandle
        fileHandle.readabilityHandler = { [buffer, dataHandler] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            buffer.append(data)
            dataHandler?(data)
        }
    }

    func stop() {
        fileHandle?.readabilityHandler = nil
        buffer.markClosed()
    }
}

nonisolated private final class CommandOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private let maxBytes: Int?
    private var data = Data()
    private var isClosed = false

    init(maxBytes: Int?) {
        self.maxBytes = maxBytes
    }

    func append(_ chunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        guard !isClosed else { return }
        guard let maxBytes else {
            data.append(chunk)
            return
        }
        guard maxBytes > 0 else { return }
        data.append(chunk)
        if data.count > maxBytes {
            data = data.suffix(maxBytes)
        }
    }

    func markClosed() {
        lock.lock()
        isClosed = true
        lock.unlock()
    }

    var stringValue: String {
        lock.lock()
        let snapshot = data
        lock.unlock()
        return String(data: snapshot, encoding: .utf8) ?? ""
    }
}
