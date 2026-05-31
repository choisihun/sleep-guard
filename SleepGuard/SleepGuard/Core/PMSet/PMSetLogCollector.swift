import Foundation

nonisolated struct PMSetLogDiagnostics: Equatable {
    var collectedAt: Date?
    var retryCount: Int
    var sessionEventLineCount: Int
    var analysisWindowStart: Date?
    var analysisWindowEnd: Date?
    var rawLogLineCount: Int
    var errorDescription: String?

    init(
        collectedAt: Date? = nil,
        retryCount: Int = 0,
        sessionEventLineCount: Int = 0,
        analysisWindowStart: Date? = nil,
        analysisWindowEnd: Date? = nil,
        rawLogLineCount: Int = 0,
        errorDescription: String? = nil
    ) {
        self.collectedAt = collectedAt
        self.retryCount = retryCount
        self.sessionEventLineCount = sessionEventLineCount
        self.analysisWindowStart = analysisWindowStart
        self.analysisWindowEnd = analysisWindowEnd
        self.rawLogLineCount = rawLogLineCount
        self.errorDescription = errorDescription
    }
}

nonisolated struct PMSetLogCollection {
    var rawLog: String
    var rawExcerpt: String
    var events: [PMSetEvent]
    var status: SleepEventAnalysisStatus
    var diagnostics: PMSetLogDiagnostics
}

nonisolated protocol PMSetLogCollecting {
    func collect(sessionStart: Date?, sessionEnd: Date?, includeRawExcerpt: Bool) async -> PMSetLogCollection
}

nonisolated struct PMSetLogCollector: PMSetLogCollecting {
    var commandRunner: PMSetCommandRunning
    var retryDelays: [UInt64]
    var paddingSeconds: TimeInterval
    var maxRawExcerptLines: Int
    var maxManualTailLines: Int

    init(
        commandRunner: PMSetCommandRunning = PMSetCommandRunner(),
        retryDelays: [UInt64] = [0, 2_000_000_000, 5_000_000_000, 10_000_000_000],
        paddingSeconds: TimeInterval = 600,
        maxRawExcerptLines: Int = 160,
        maxManualTailLines: Int = 500
    ) {
        self.commandRunner = commandRunner
        self.retryDelays = retryDelays
        self.paddingSeconds = paddingSeconds
        self.maxRawExcerptLines = maxRawExcerptLines
        self.maxManualTailLines = maxManualTailLines
    }

    func collect(sessionStart: Date?, sessionEnd: Date?, includeRawExcerpt: Bool) async -> PMSetLogCollection {
        let delays = retryDelays.isEmpty ? [UInt64(0)] : retryDelays
        let window = analysisWindow(start: sessionStart, end: sessionEnd)
        var lastRawLog = ""
        var lastRawLogLineCount = 0
        var lastCollectedAt: Date?
        var lastError: String?

        for (attemptIndex, delay) in delays.enumerated() {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }

            let accumulator = PMSetLogLineAccumulator(
                sessionStart: sessionStart,
                sessionEnd: sessionEnd,
                paddingSeconds: paddingSeconds,
                includeRawExcerpt: includeRawExcerpt,
                maxRawExcerptLines: maxRawExcerptLines,
                maxManualTailLines: maxManualTailLines
            )
            do {
                try await commandRunner.streamLog(from: window.start, to: window.end) { line in
                    accumulator.consume(line)
                }
                let collectedAt = Date()
                let parsed = accumulator.snapshot()
                lastCollectedAt = collectedAt
                lastRawLog = parsed.rawExcerpt
                lastRawLogLineCount = parsed.rawLogLineCount

                guard parsed.rawLogLineCount > 0 else {
                    lastError = CommandError.emptyOutput.localizedDescription
                    continue
                }

                let diagnostics = PMSetLogDiagnostics(
                    collectedAt: collectedAt,
                    retryCount: attemptIndex,
                    sessionEventLineCount: parsed.sessionEventLineCount,
                    analysisWindowStart: window.start,
                    analysisWindowEnd: window.end,
                    rawLogLineCount: parsed.rawLogLineCount,
                    errorDescription: parsed.events.isEmpty ? "No pmset events matched the sleep session analysis window." : nil
                )

                if !parsed.events.isEmpty {
                    return PMSetLogCollection(
                        rawLog: parsed.rawExcerpt,
                        rawExcerpt: parsed.rawExcerpt,
                        events: parsed.events,
                        status: .available,
                        diagnostics: diagnostics
                    )
                }

                lastError = diagnostics.errorDescription
            } catch {
                let collectedAt = Date()
                let parsed = accumulator.snapshot()
                lastCollectedAt = collectedAt
                lastRawLog = parsed.rawExcerpt
                lastRawLogLineCount = parsed.rawLogLineCount
                lastError = error.localizedDescription

                if !parsed.events.isEmpty {
                    return PMSetLogCollection(
                        rawLog: parsed.rawExcerpt,
                        rawExcerpt: parsed.rawExcerpt,
                        events: parsed.events,
                        status: .available,
                        diagnostics: PMSetLogDiagnostics(
                            collectedAt: collectedAt,
                            retryCount: attemptIndex,
                            sessionEventLineCount: parsed.sessionEventLineCount,
                            analysisWindowStart: window.start,
                            analysisWindowEnd: window.end,
                            rawLogLineCount: parsed.rawLogLineCount,
                            errorDescription: "pmset log command failed after matching session events were collected: \(error.localizedDescription)"
                        )
                    )
                }
            }
        }

        return PMSetLogCollection(
            rawLog: lastRawLog,
            rawExcerpt: sessionStart == nil || sessionEnd == nil ? lastRawLog : "",
            events: [],
            status: .unavailable,
            diagnostics: PMSetLogDiagnostics(
                collectedAt: lastCollectedAt,
                retryCount: max(delays.count - 1, 0),
                sessionEventLineCount: 0,
                analysisWindowStart: window.start,
                analysisWindowEnd: window.end,
                rawLogLineCount: lastRawLogLineCount,
                errorDescription: lastError
            )
        )
    }

    private func analysisWindow(start: Date?, end: Date?) -> (start: Date?, end: Date?) {
        guard let start, let end else {
            return (nil, nil)
        }
        return (
            start.addingTimeInterval(-paddingSeconds),
            end.addingTimeInterval(paddingSeconds)
        )
    }
}

nonisolated private struct ParsedPMSetLog {
    var events: [PMSetEvent]
    var rawExcerpt: String
    var sessionEventLineCount: Int
    var rawLogLineCount: Int
}

nonisolated private final class PMSetLogLineAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private let parser = PMSetLogParser()
    private let windowStart: Date?
    private let windowEnd: Date?
    private let windowStartText: String?
    private let windowEndText: String?
    private let includeRawExcerpt: Bool
    private let maxRawExcerptLines: Int
    private let maxManualTailLines: Int
    private var rawLogLineCount = 0
    private var events: [PMSetEvent] = []
    private var excerptLines: [String] = []
    private var excerptLineSet: Set<String> = []
    private var manualTailLines: [String] = []

    init(
        sessionStart: Date?,
        sessionEnd: Date?,
        paddingSeconds: TimeInterval,
        includeRawExcerpt: Bool,
        maxRawExcerptLines: Int,
        maxManualTailLines: Int
    ) {
        if let sessionStart, let sessionEnd {
            let formatter = Self.makeTimestampFormatter()
            let windowStart = sessionStart.addingTimeInterval(-paddingSeconds)
            let windowEnd = sessionEnd.addingTimeInterval(paddingSeconds)
            self.windowStart = windowStart
            self.windowEnd = windowEnd
            self.windowStartText = formatter.string(from: windowStart)
            self.windowEndText = formatter.string(from: windowEnd)
        } else {
            self.windowStart = nil
            self.windowEnd = nil
            self.windowStartText = nil
            self.windowEndText = nil
        }
        self.includeRawExcerpt = includeRawExcerpt
        self.maxRawExcerptLines = max(maxRawExcerptLines, 0)
        self.maxManualTailLines = max(maxManualTailLines, 0)
    }

    func consume(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        lock.lock()
        rawLogLineCount += 1

        guard let windowStartText, let windowEndText else {
            appendManualTail(line)
            lock.unlock()
            return
        }

        guard let timestampText = Self.timestampText(from: trimmed),
              timestampText >= windowStartText,
              timestampText <= windowEndText else {
            lock.unlock()
            return
        }

        let parsedEvents = parser.parseLine(line)
        if !parsedEvents.isEmpty {
            events.append(contentsOf: parsedEvents)
            appendExcerptLine(line)
        }
        lock.unlock()
    }

    func snapshot() -> ParsedPMSetLog {
        lock.lock()
        let rawLogLineCount = rawLogLineCount
        let windowedEvents = events.sorted { $0.timestamp < $1.timestamp }
        let manualTail = manualTailLines
        let excerpt = excerptLines.joined(separator: "\n")
        lock.unlock()

        guard windowStart == nil || windowEnd == nil else {
            return ParsedPMSetLog(
                events: windowedEvents,
                rawExcerpt: includeRawExcerpt ? excerpt : "",
                sessionEventLineCount: Set(windowedEvents.map(\.rawLine)).count,
                rawLogLineCount: rawLogLineCount
            )
        }

        let tail = manualTail.joined(separator: "\n")
        let tailEvents = PMSetLogParser().parse(tail)
        return ParsedPMSetLog(
            events: tailEvents,
            rawExcerpt: includeRawExcerpt ? tail : "",
            sessionEventLineCount: Set(tailEvents.map(\.rawLine)).count,
            rawLogLineCount: rawLogLineCount
        )
    }

    private func appendManualTail(_ line: String) {
        guard maxManualTailLines > 0 else { return }
        manualTailLines.append(line)
        if manualTailLines.count > maxManualTailLines {
            manualTailLines.removeFirst(manualTailLines.count - maxManualTailLines)
        }
    }

    private func appendExcerptLine(_ line: String) {
        guard includeRawExcerpt, maxRawExcerptLines > 0, excerptLineSet.insert(line).inserted else { return }
        guard excerptLines.count < maxRawExcerptLines else { return }
        excerptLines.append(line)
    }

    private static func makeTimestampFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }

    private static func timestampText(from line: String) -> String? {
        guard line.count >= 19,
              line[line.startIndex].isNumber else {
            return nil
        }
        return String(line.prefix(19))
    }
}
