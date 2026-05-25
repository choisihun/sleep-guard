import Foundation

struct BatteryDrainResult: Equatable {
    var drainPercent: Int
    var durationSeconds: TimeInterval
    var drainPerHour: Double
}

struct BatteryDrainCalculator {
    func calculate(start: Date, end: Date, batteryBefore: Int, batteryAfter: Int) -> BatteryDrainResult {
        let duration = max(0, end.timeIntervalSince(start))
        let drain = max(0, batteryBefore - batteryAfter)
        let hours = max(duration / 3600, 1.0 / 60.0)
        let perHour = Double(drain) / hours
        return BatteryDrainResult(
            drainPercent: drain,
            durationSeconds: duration,
            drainPerHour: perHour.isFinite ? perHour : 0
        )
    }
}
