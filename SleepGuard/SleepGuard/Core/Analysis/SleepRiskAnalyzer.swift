import Foundation

struct SleepRiskInput {
    var drainPercent: Int
    var drainPerHour: Double
    var durationSeconds: TimeInterval = 0
    var darkWakeCount: Int
    var wakeRequestCount: Int
    var assertionCount: Int
    var bluetoothDelayCount: Int
    var tcpKeepAliveCount: Int
    var usbCWakeCount: Int = 0
    var suspiciousProcessNames: [String]
}

struct SleepRiskResult: Equatable {
    var score: Int
    var level: SleepRiskLevel
}

struct SleepRiskAnalyzer {
    func analyze(_ input: SleepRiskInput) -> SleepRiskResult {
        var score = 0
        let isLongSleepNotableDrain = BatteryDrainThresholds.isLongSleepNotableDrain(
            drainPercent: input.drainPercent,
            durationSeconds: input.durationSeconds
        )
        score += min(input.drainPercent * 2, 30)
        if input.drainPercent >= BatteryDrainThresholds.highTotalDrainPercent {
            score += 15
        } else if isLongSleepNotableDrain {
            score += 17
        } else if input.drainPercent >= BatteryDrainThresholds.notableTotalDrainPercent {
            score += 8
        }
        if input.drainPerHour > BatteryDrainThresholds.highDrainPerHour { score += 20 }
        if input.drainPerHour > BatteryDrainThresholds.severeDrainPerHour { score += 15 }
        score += min(input.darkWakeCount, 30)
        score += min(input.wakeRequestCount * 2, 20)
        score += min(input.assertionCount * 5, 25)
        score += min(input.bluetoothDelayCount * 3, 15)
        score += input.tcpKeepAliveCount > 0 ? 10 : 0
        score += min(input.usbCWakeCount * 2, 10)

        score += min(input.suspiciousProcessNames.count * 3, 15)
        if input.drainPercent == 0 && input.drainPerHour == 0 {
            score = min(score, 60)
        }

        let bounded = max(0, min(100, score))
        let level: SleepRiskLevel
        switch bounded {
        case 0..<35: level = .good
        case 35..<70: level = .caution
        default: level = .bad
        }
        return SleepRiskResult(score: bounded, level: level)
    }
}
