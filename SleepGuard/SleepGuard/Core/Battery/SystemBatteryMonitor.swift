import Foundation
import IOKit.ps

struct SystemBatteryMonitor: BatteryMonitor {
    func currentBatteryInfo() -> BatteryInfo? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any] else {
            return nil
        }

        let current = description[kIOPSCurrentCapacityKey as String] as? Int
        let maximum = description[kIOPSMaxCapacityKey as String] as? Int
        let percent: Int
        if let current, let maximum, maximum > 0 {
            percent = Int((Double(current) / Double(maximum) * 100).rounded())
        } else {
            percent = current ?? 0
        }

        let sourceState = description[kIOPSPowerSourceStateKey as String] as? String
        let powerSource: BatteryPowerSource
        if sourceState == kIOPSACPowerValue {
            powerSource = .ac
        } else if sourceState == kIOPSBatteryPowerValue {
            powerSource = .battery
        } else {
            powerSource = .unknown
        }

        let rawTimeRemaining = description[kIOPSTimeToEmptyKey as String] as? Int
        let timeRemaining = rawTimeRemaining.flatMap { $0 >= 0 ? $0 : nil }

        return BatteryInfo(
            percent: max(0, min(100, percent)),
            isCharging: description[kIOPSIsChargingKey as String] as? Bool ?? false,
            powerSource: powerSource,
            timeRemainingMinutes: timeRemaining,
            timestamp: Date()
        )
    }
}
