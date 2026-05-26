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
            guard app.bundleId != nil, !isCurrentApplication(app) else { return nil }
            let snapshot = aggregatedSnapshot(for: app, snapshots: snapshots)
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
            arguments: ["-axo", "pid=,ppid=,pcpu=,rss="]
        )
        return ProcessResourceSnapshot.parse(psOutput: output)
    }

    private func aggregatedSnapshot(
        for app: RunningAppInfo,
        snapshots: [pid_t: ProcessResourceSnapshot]
    ) -> ProcessResourceSnapshot {
        var cpuPercent = 0.0
        var residentMemoryKB = 0

        for snapshot in snapshots.values where snapshot.belongsToAppProcess(app.processIdentifier, snapshots: snapshots) {
            cpuPercent += snapshot.cpuPercent
            residentMemoryKB += snapshot.residentMemoryKB
        }

        return ProcessResourceSnapshot(
            pid: app.processIdentifier,
            parentProcessId: snapshots[app.processIdentifier]?.parentProcessId,
            cpuPercent: cpuPercent,
            residentMemoryKB: residentMemoryKB
        )
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
            reasons.append("CPU 높음")
        }
        if memoryMB >= scoring.memoryReasonMinimumMegabytes {
            reasons.append("메모리 사용 큼")
        }
        if app.activationPolicy == .regular {
            reasons.append("실행 중인 앱")
        }
        return reasons
    }

    private func isCurrentApplication(_ app: RunningAppInfo) -> Bool {
        if app.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            return true
        }
        if let bundleId = app.bundleId, bundleId == Bundle.main.bundleIdentifier {
            return true
        }
        return false
    }
}

struct ProcessResourceSnapshot: Hashable {
    var pid: pid_t
    var parentProcessId: pid_t?
    var cpuPercent: Double
    var residentMemoryKB: Int

    static func parse(psOutput: String) -> [pid_t: ProcessResourceSnapshot] {
        psOutput
            .split(separator: "\n")
            .reduce(into: [pid_t: ProcessResourceSnapshot]()) { result, line in
                let fields = line.split(whereSeparator: \.isWhitespace)
                guard fields.count >= 3,
                      let pid = pid_t(String(fields[0])) else {
                    return
                }
                let parsed: (parentProcessId: pid_t?, cpuPercent: Double, residentMemoryKB: Int)?
                if fields.count >= 4,
                   let parentProcessId = pid_t(String(fields[1])),
                   let cpuPercent = Double(fields[2]),
                   let residentMemoryKB = Int(fields[3]) {
                    parsed = (parentProcessId, cpuPercent, residentMemoryKB)
                } else if let cpuPercent = Double(fields[1]),
                          let residentMemoryKB = Int(fields[2]) {
                    parsed = (nil, cpuPercent, residentMemoryKB)
                } else {
                    parsed = nil
                }
                guard let parsed else { return }
                result[pid] = ProcessResourceSnapshot(
                    pid: pid,
                    parentProcessId: parsed.parentProcessId,
                    cpuPercent: parsed.cpuPercent,
                    residentMemoryKB: parsed.residentMemoryKB
                )
            }
    }

    func belongsToAppProcess(_ appProcessId: pid_t, snapshots: [pid_t: ProcessResourceSnapshot]) -> Bool {
        if pid == appProcessId {
            return true
        }

        var seen = Set<pid_t>()
        var parent = parentProcessId
        while let currentParent = parent, !seen.contains(currentParent) {
            if currentParent == appProcessId {
                return true
            }
            seen.insert(currentParent)
            parent = snapshots[currentParent]?.parentProcessId
        }
        return false
    }
}
