import Foundation

enum ManagedAppCategory: String, Codable, CaseIterable, Identifiable {
    case development
    case browser
    case communication
    case media
    case cloud
    case vpn
    case utility
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .development: "Development"
        case .browser: "Browser"
        case .communication: "Communication"
        case .media: "Media"
        case .cloud: "Cloud"
        case .vpn: "VPN"
        case .utility: "Utility"
        case .unknown: "Unknown"
        }
    }
}

enum ManagedAppRiskLevel: String, Codable, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }
}

struct ManagedAppConfiguration: Identifiable, Codable, Hashable {
    var id: UUID
    var bundleId: String
    var displayName: String
    var appURLString: String?
    var isEnabled: Bool
    var shouldQuitBeforeSleep: Bool
    var shouldRestoreAfterWake: Bool
    var allowsForceTerminate: Bool
    var terminationTimeoutSeconds: Double
    var category: ManagedAppCategory
    var riskLevel: ManagedAppRiskLevel
}
