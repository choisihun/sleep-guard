import AppKit
import Foundation

struct AppEnergyImpactScoring: Decodable, Equatable {
    var highRiskScoreMinimum: Double
    var mediumRiskScoreMinimum: Double
    var cpuScoreMultiplier: Double
    var maximumCPUScore: Double
    var memoryMegabytesPerPoint: Double
    var maximumMemoryScore: Double
    var foregroundScore: Double
    var visibleScore: Double
    var maximumScore: Double
    var minimumIncludedScore: Double
    var cpuReasonMinimum: Double
    var memoryReasonMinimumMegabytes: Double

    func level(for score: Double) -> ManagedAppRiskLevel {
        if score >= highRiskScoreMinimum { return .high }
        if score >= mediumRiskScoreMinimum { return .medium }
        return .low
    }
}

struct AppEnergyImpact: Identifiable, Codable, Hashable {
    var id: Int32 { app.processIdentifier }
    var app: RunningAppInfo
    var cpuPercent: Double
    var memoryMB: Double
    var score: Double
    var level: ManagedAppRiskLevel
    var reasons: [String]

    var scoreText: String {
        "\(Int(score.rounded()))"
    }

    var detailText: String {
        let cpu = String(format: "CPU %.1f%%", cpuPercent)
        let memory = String(format: "%.0f MB", memoryMB)
        return "\(cpu) · \(memory)"
    }
}

protocol AppEnergyImpactProviding {
    func impacts(for apps: [RunningAppInfo]) async -> [AppEnergyImpact]
}

struct SystemAppEnergyImpactProvider: AppEnergyImpactProviding {
    private let runner: CommandRunning
    private let scoring: AppEnergyImpactScoring
    private let psURL = URL(fileURLWithPath: "/bin/ps")

    init(
        runner: CommandRunning = SystemCommandRunner(timeoutSeconds: 5),
        scoring: AppEnergyImpactScoring
    ) {
        self.runner = runner
        self.scoring = scoring
    }

    func impacts(for apps: [RunningAppInfo]) async -> [AppEnergyImpact] {
        let snapshots = (try? await processSnapshots()) ?? [:]
        return apps.compactMap { app in
            guard app.bundleId != nil else { return nil }
            let snapshot = snapshots[app.processIdentifier] ?? ProcessResourceSnapshot(
                pid: app.processIdentifier,
                cpuPercent: 0,
                residentMemoryKB: 0
            )
            let memoryMB = Double(snapshot.residentMemoryKB) / 1024
            let score = estimatedScore(app: app, snapshot: snapshot)
            guard score > scoring.minimumIncludedScore else { return nil }

            return AppEnergyImpact(
                app: app,
                cpuPercent: snapshot.cpuPercent,
                memoryMB: memoryMB,
                score: score,
                level: scoring.level(for: score),
                reasons: reasons(app: app, snapshot: snapshot, memoryMB: memoryMB)
            )
        }
        .sorted {
            if $0.score == $1.score {
                return $0.app.displayName.localizedCaseInsensitiveCompare($1.app.displayName) == .orderedAscending
            }
            return $0.score > $1.score
        }
    }

    private func processSnapshots() async throws -> [pid_t: ProcessResourceSnapshot] {
        let output = try await runner.run(
            executableURL: psURL,
            arguments: ["-axo", "pid=,pcpu=,rss="]
        )
        return ProcessResourceSnapshot.parse(psOutput: output)
    }

    private func estimatedScore(
        app: RunningAppInfo,
        snapshot: ProcessResourceSnapshot
    ) -> Double {
        let cpuScore = min(snapshot.cpuPercent * scoring.cpuScoreMultiplier, scoring.maximumCPUScore)
        let memoryMB = Double(snapshot.residentMemoryKB) / 1024
        let memoryScore = min(memoryMB / scoring.memoryMegabytesPerPoint, scoring.maximumMemoryScore)
        let foregroundScore = app.activationPolicy == .regular ? scoring.foregroundScore : 0
        let visibleScore = app.isHidden ? 0 : scoring.visibleScore
        return min(scoring.maximumScore, cpuScore + memoryScore + foregroundScore + visibleScore)
    }

    private func reasons(
        app: RunningAppInfo,
        snapshot: ProcessResourceSnapshot,
        memoryMB: Double
    ) -> [String] {
        var reasons: [String] = []
        if snapshot.cpuPercent >= scoring.cpuReasonMinimum {
            reasons.append(String(format: "CPU %.1f%%", snapshot.cpuPercent))
        }
        if memoryMB >= scoring.memoryReasonMinimumMegabytes {
            reasons.append(String(format: "메모리 %.0f MB", memoryMB))
        }
        if app.activationPolicy == .regular {
            reasons.append("실행 중인 앱")
        }
        return reasons
    }
}

struct ProcessResourceSnapshot: Hashable {
    var pid: pid_t
    var cpuPercent: Double
    var residentMemoryKB: Int

    static func parse(psOutput: String) -> [pid_t: ProcessResourceSnapshot] {
        psOutput
            .split(separator: "\n")
            .reduce(into: [pid_t: ProcessResourceSnapshot]()) { result, line in
                let fields = line.split(whereSeparator: \.isWhitespace)
                guard fields.count >= 3,
                      let pid = pid_t(String(fields[0])),
                      let cpuPercent = Double(fields[1]),
                      let residentMemoryKB = Int(fields[2]) else {
                    return
                }
                result[pid] = ProcessResourceSnapshot(
                    pid: pid,
                    cpuPercent: cpuPercent,
                    residentMemoryKB: residentMemoryKB
                )
            }
    }
}
