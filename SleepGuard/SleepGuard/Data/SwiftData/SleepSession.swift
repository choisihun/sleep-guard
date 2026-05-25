import Foundation
import SwiftData

@Model
final class SleepSession {
    var id: UUID
    var sleepStartedAt: Date
    var wokeAt: Date?
    var batteryBefore: Int
    var batteryAfter: Int?
    var drainPercent: Int
    var drainPerHour: Double
    var durationSeconds: TimeInterval
    var wasManualSleep: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        sleepStartedAt: Date,
        wokeAt: Date? = nil,
        batteryBefore: Int,
        batteryAfter: Int? = nil,
        drainPercent: Int = 0,
        drainPerHour: Double = 0,
        durationSeconds: TimeInterval = 0,
        wasManualSleep: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sleepStartedAt = sleepStartedAt
        self.wokeAt = wokeAt
        self.batteryBefore = batteryBefore
        self.batteryAfter = batteryAfter
        self.drainPercent = drainPercent
        self.drainPerHour = drainPerHour
        self.durationSeconds = durationSeconds
        self.wasManualSleep = wasManualSleep
        self.createdAt = createdAt
    }
}
