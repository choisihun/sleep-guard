import Foundation

protocol BatteryMonitor {
    func currentBatteryInfo() -> BatteryInfo?
}
