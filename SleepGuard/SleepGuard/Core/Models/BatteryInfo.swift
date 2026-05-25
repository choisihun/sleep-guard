import Foundation

enum BatteryPowerSource: String, Codable, CaseIterable {
    case battery
    case ac
    case unknown

    var displayName: String {
        switch self {
        case .battery: "Battery"
        case .ac: "AC Power"
        case .unknown: "Unknown"
        }
    }
}

struct BatteryInfo: Codable, Equatable {
    var percent: Int
    var isCharging: Bool
    var powerSource: BatteryPowerSource
    var timeRemainingMinutes: Int?
    var timestamp: Date

    static let unknown = BatteryInfo(
        percent: 0,
        isCharging: false,
        powerSource: .unknown,
        timeRemainingMinutes: nil,
        timestamp: Date()
    )
}
