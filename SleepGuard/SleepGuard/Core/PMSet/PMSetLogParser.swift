import Foundation

struct PMSetLogParser {
    var wakeRequestParser = PMSetWakeRequestParser()
    var assertionParser = PMSetAssertionParser()

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter
    }

    func parse(_ rawLog: String) -> [PMSetEvent] {
        rawLog
            .split(separator: "\n", omittingEmptySubsequences: true)
            .flatMap { parseLine(String($0)) }
            .sorted { $0.timestamp < $1.timestamp }
    }

    func excerpt(_ rawLog: String, around start: Date?, end: Date?, maxLines: Int = 160) -> String {
        guard let start, let end else {
            return rawLog.split(separator: "\n").suffix(maxLines).joined(separator: "\n")
        }
        let events = parse(rawLog).filter { $0.timestamp >= start.addingTimeInterval(-600) && $0.timestamp <= end.addingTimeInterval(600) }
        let lines = events.map(\.rawLine)
        return Array(lines.prefix(maxLines)).joined(separator: "\n")
    }

    private func parseLine(_ line: String) -> [PMSetEvent] {
        let timestamp = parseTimestamp(from: line) ?? Date.distantPast
        let lower = line.lowercased()
        let batteryCharge = parseBatteryCharge(from: line)
        let tcpActive = lower.contains("tcpkeepalive=active")
        var category: PMSetEventCategory = .other
        var wakeReason: String?

        let assertion = assertionParser.parse(line: line)
        let wakeRequests = wakeRequestParser.requests(in: line)

        if lower.contains("entering sleep state") {
            category = .sleep
        } else if lower.contains("darkwake") {
            category = .darkWake
            wakeReason = parseWakeReason(from: line)
        } else if lower.contains("wake requests") || lower.contains("wake request") {
            category = .wakeRequest
        } else if lower.contains("wake from") || lower.contains(" wake ") {
            category = .wake
            wakeReason = parseWakeReason(from: line)
        } else if assertion.assertionType != nil || lower.contains("assertions") {
            category = .assertion
        } else if lower.contains("client acks") || lower.contains("pm client") {
            category = .pmClientAck
        } else if lower.contains("sleepservices") || lower.contains("sleepservice") {
            category = .sleepService
        } else if lower.contains("bluetooth") && lower.contains("sleep") {
            category = .bluetooth
        } else if lower.contains("maintenancewake") || lower.contains("maintenance wake") {
            category = .maintenanceWake
        }

        if tcpActive {
            category = category == .other ? .tcpKeepAlive : category
        }

        var events = [
            PMSetEvent(
                timestamp: timestamp,
                category: category,
                message: line,
                processName: assertion.processName,
                assertionType: assertion.assertionType,
                wakeReason: wakeReason,
                batteryCharge: batteryCharge,
                isTCPKeepAliveActive: tcpActive,
                rawLine: line
            )
        ]

        for request in wakeRequests {
            events.append(
                PMSetEvent(
                    timestamp: timestamp,
                    category: .wakeRequest,
                    message: line,
                    processName: request.processName,
                    wakeReason: request.requestName,
                    batteryCharge: batteryCharge,
                    isTCPKeepAliveActive: tcpActive,
                    rawLine: line
                )
            )
        }
        return events
    }

    private func parseTimestamp(from line: String) -> Date? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 25 else { return nil }
        return dateFormatter.date(from: String(trimmed.prefix(25)))
    }

    private func parseBatteryCharge(from line: String) -> Int? {
        guard let chargeRange = line.range(of: "Charge:", options: [.caseInsensitive]) else { return nil }
        let suffix = line[chargeRange.upperBound...].drop { $0.isWhitespace }
        let digits = suffix.prefix { $0.isNumber }
        return Int(digits)
    }

    private func parseWakeReason(from line: String) -> String? {
        if let range = line.range(of: "due to", options: [.caseInsensitive]) {
            let suffix = line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            return suffix.split(separator: " ").first.map(String.init)
        }
        if let range = line.range(of: "Wake from", options: [.caseInsensitive]) {
            let suffix = line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            return suffix.split(separator: " ").first.map(String.init)
        }
        if let range = line.range(of: "reason:", options: [.caseInsensitive]) {
            let suffix = line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            return suffix.split(separator: " ").first.map(String.init)
        }
        return nil
    }
}
