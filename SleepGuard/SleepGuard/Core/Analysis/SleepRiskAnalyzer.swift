import Foundation

struct SleepRiskInput {
    var drainPercent: Int
    var drainPerHour: Double
    var darkWakeCount: Int
    var wakeRequestCount: Int
    var assertionCount: Int
    var bluetoothDelayCount: Int
    var tcpKeepAliveCount: Int
    var suspiciousProcessNames: [String]
}

struct SleepRiskResult: Equatable {
    var score: Int
    var level: SleepRiskLevel
}

struct SleepRiskAnalyzer {
    func analyze(_ input: SleepRiskInput) -> SleepRiskResult {
        var score = 0
        score += min(input.drainPercent * 4, 30)
        if input.drainPerHour > 1.5 { score += 20 }
        if input.drainPerHour > 3 { score += 15 }
        score += min(input.darkWakeCount, 30)
        score += min(input.wakeRequestCount * 2, 20)
        score += min(input.assertionCount * 5, 25)
        score += min(input.bluetoothDelayCount * 3, 15)
        score += input.tcpKeepAliveCount > 0 ? 10 : 0

        score += min(input.suspiciousProcessNames.count * 3, 15)

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
