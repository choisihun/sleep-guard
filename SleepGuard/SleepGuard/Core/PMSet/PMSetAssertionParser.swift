import Foundation

nonisolated struct PMSetAssertionParser {
    private let knownAssertionTypes = [
        "PreventUserIdleSystemSleep",
        "PreventUserIdleDisplaySleep",
        "PreventSystemSleep",
        "InternalPreventSleep",
        "MaintenanceWake",
        "BackgroundTask",
        "ApplePushServiceTask",
        "NoDisplaySleepAssertion",
        "NoIdleSleepAssertion",
        "NetworkClientActive",
        "UserIsActive",
        "DisplayWake",
        "SystemIsActive",
        "InteractivePushServiceTask"
    ]

    func parse(line: String) -> (assertionType: String?, processName: String?) {
        let assertionType = knownAssertionTypes.first { line.range(of: $0, options: [.caseInsensitive]) != nil }
        return (assertionType, processNameAfterPID(in: line))
    }

    private func processNameAfterPID(in line: String) -> String? {
        guard let pidRange = line.range(of: "pid ", options: [.caseInsensitive]) else { return nil }
        let suffix = line[pidRange.upperBound...]
        guard let closingParen = suffix.firstIndex(of: ")") else { return nil }
        let beforeParen = suffix[..<closingParen]
        guard let openParen = beforeParen.lastIndex(of: "(") else { return nil }
        let name = beforeParen[beforeParen.index(after: openParen)...].trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }
}
