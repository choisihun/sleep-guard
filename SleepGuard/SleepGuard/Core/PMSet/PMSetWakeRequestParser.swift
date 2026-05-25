import Foundation

struct PMSetWakeRequest: Hashable {
    var processName: String
    var requestName: String?
    var deltaSeconds: Int?
    var wakeAtText: String?
    var info: String?
}

struct PMSetWakeRequestParser {
    func processNames(in line: String) -> [String] {
        let parsedNames = requests(in: line).map(\.processName)
        if !parsedNames.isEmpty {
            return Array(Set(parsedNames)).sorted()
        }

        let lower = line.lowercased()
        guard lower.contains("wake requests") || lower.contains("wake request") else { return [] }

        if let requester = value(after: "requested by", in: line) {
            return [requester]
        }
        return []
    }

    func requests(in line: String) -> [PMSetWakeRequest] {
        let lower = line.lowercased()
        guard lower.contains("wake requests") || lower.contains("wake request") else { return [] }

        return bracketBodies(in: line).compactMap { body in
            guard let processName = value(for: "process", in: body) else { return nil }
            return PMSetWakeRequest(
                processName: processName,
                requestName: value(for: "request", in: body),
                deltaSeconds: value(for: "deltaSecs", in: body).flatMap(Int.init),
                wakeAtText: wakeAtValue(in: body),
                info: quotedValue(for: "info", in: body)
            )
        }
    }

    private func bracketBodies(in line: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"\[([^\]]+)\]"#) else { return [] }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return regex.matches(in: line, range: range).compactMap { match in
            guard let bodyRange = Range(match.range(at: 1), in: line) else { return nil }
            return String(line[bodyRange])
        }
    }

    private func value(for key: String, in text: String) -> String? {
        let pattern = #"(?:^|\s)\*?\#(key)=([^\s\]]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[valueRange])
    }

    private func wakeAtValue(in text: String) -> String? {
        let pattern = #"wakeAt=(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[valueRange])
    }

    private func quotedValue(for key: String, in text: String) -> String? {
        let pattern = #"\#(key)="([^"]*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[valueRange])
    }

    private func value(after token: String, in line: String) -> String? {
        guard let range = line.range(of: token, options: [.caseInsensitive]) else { return nil }
        let suffix = line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        return suffix.split(whereSeparator: { $0 == "," || $0 == ";" || $0 == ")" }).first.map(String.init)
    }
}
