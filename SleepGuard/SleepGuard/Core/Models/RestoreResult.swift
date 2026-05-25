import Foundation

enum RestoreResult: String, Codable, CaseIterable {
    case success
    case failed
    case appURLMissing
    case skippedByUserSetting
}
