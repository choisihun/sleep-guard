import Foundation
import Testing
@testable import SleepGuard

struct BatteryDrainCalculatorTests {
    @Test func calculatesDrainPerHour() {
        let calculator = BatteryDrainCalculator()
        let start = Date(timeIntervalSince1970: 0)
        let end = start.addingTimeInterval(4 * 3600)

        let result = calculator.calculate(start: start, end: end, batteryBefore: 73, batteryAfter: 67)

        #expect(result.drainPercent == 6)
        #expect(result.durationSeconds == 14_400)
        #expect(abs(result.drainPerHour - 1.5) < 0.001)
    }
}
