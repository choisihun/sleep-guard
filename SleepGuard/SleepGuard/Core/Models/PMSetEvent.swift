import Foundation

enum PMSetEventCategory: String, Codable, CaseIterable, Identifiable {
    case sleep
    case wake
    case darkWake
    case wakeRequest
    case assertion
    case pmClientAck
    case sleepService
    case bluetooth
    case tcpKeepAlive
    case maintenanceWake
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sleep: "Sleep"
        case .wake: "Wake"
        case .darkWake: "DarkWake"
        case .wakeRequest: "Wake Requests"
        case .assertion: "Assertions"
        case .pmClientAck: "PM Client Acks"
        case .sleepService: "SleepService"
        case .bluetooth: "Bluetooth"
        case .tcpKeepAlive: "TCP KeepAlive"
        case .maintenanceWake: "Maintenance Wake"
        case .other: "Other"
        }
    }
}

struct PMSetEvent: Identifiable, Codable, Hashable {
    var id: UUID
    var timestamp: Date
    var category: PMSetEventCategory
    var message: String
    var processName: String?
    var assertionType: String?
    var wakeReason: String?
    var batteryCharge: Int?
    var isTCPKeepAliveActive: Bool
    var rawLine: String

    init(
        id: UUID = UUID(),
        timestamp: Date,
        category: PMSetEventCategory,
        message: String,
        processName: String? = nil,
        assertionType: String? = nil,
        wakeReason: String? = nil,
        batteryCharge: Int? = nil,
        isTCPKeepAliveActive: Bool = false,
        rawLine: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.message = message
        self.processName = processName
        self.assertionType = assertionType
        self.wakeReason = wakeReason
        self.batteryCharge = batteryCharge
        self.isTCPKeepAliveActive = isTCPKeepAliveActive
        self.rawLine = rawLine
    }
}
