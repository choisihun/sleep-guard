import Foundation

enum TerminationMode: String, Codable, CaseIterable {
    case graceful
    case forceIfAllowed
}

enum TerminationResult: String, Codable, CaseIterable {
    case success
    case failed
    case timedOut
    case skippedProtected
    case skippedNotAllowed
    case forceTerminated
    case appNotFound

    var isTerminated: Bool {
        self == .success || self == .forceTerminated
    }
}
