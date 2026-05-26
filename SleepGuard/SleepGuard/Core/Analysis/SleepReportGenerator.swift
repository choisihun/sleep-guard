import Foundation

struct SleepReportDraft {
    var riskScore: Int
    var riskLevel: SleepRiskLevel
    var summaryText: String
    var recommendations: [String]
    var darkWakeCount: Int
    var wakeRequestCount: Int
    var assertionCount: Int
    var bluetoothDelayCount: Int
    var tcpKeepAliveCount: Int
    var rawPMSetExcerpt: String
    var topSuspectNames: [String]
    var eventAnalysisStatus: SleepEventAnalysisStatus
    var pmsetDiagnostics: PMSetLogDiagnostics?
}

struct SleepReportGenerator {
    var analyzer = SleepRiskAnalyzer()
    var recommendationEngine = RecommendationEngine()

    func generate(
        session: SleepSession,
        events: [PMSetEvent],
        rawPMSetExcerpt: String,
        runningApps: [RunningAppRecord],
        terminatedApps: [RunningAppRecord],
        restoredApps: [RunningAppRecord],
        eventAnalysisStatus: SleepEventAnalysisStatus = .available,
        pmsetDiagnostics: PMSetLogDiagnostics? = nil
    ) -> SleepReportDraft {
        let canAnalyzeEvents = !eventAnalysisStatus.isUnavailable
        let darkWakeCount = canAnalyzeEvents ? events.filter { $0.category == .darkWake }.count : 0
        let wakeRequestEvents = canAnalyzeEvents ? events.filter { $0.category == .wakeRequest } : []
        let wakeRequestCount = canAnalyzeEvents ? Set(wakeRequestEvents.map(\.rawLine)).count : 0
        let assertionEvents = canAnalyzeEvents ? events.filter { $0.category == .assertion } : []
        let bluetoothDelayCount = canAnalyzeEvents ? events.filter {
            $0.category == .bluetooth ||
                $0.rawLine.localizedCaseInsensitiveContains("bluetooth sleep is slow") ||
                $0.rawLine.localizedCaseInsensitiveContains("bluetooth.sleep is slow")
        }.count : 0
        let tcpKeepAliveCount = canAnalyzeEvents ? events.filter(\.isTCPKeepAliveActive).count : 0

        let wakeProcesses = rankedNames(wakeRequestEvents.compactMap(\.processName))
        let assertionProcesses = rankedNames(assertionEvents.compactMap(\.processName))
        let runningNames = runningApps.map(\.displayName)
        let topSuspects = (wakeProcesses + assertionProcesses).uniqued()

        let risk = analyzer.analyze(
            SleepRiskInput(
                drainPercent: session.drainPercent,
                drainPerHour: session.drainPerHour,
                darkWakeCount: darkWakeCount,
                wakeRequestCount: wakeRequestCount,
                assertionCount: assertionEvents.count,
                bluetoothDelayCount: bluetoothDelayCount,
                tcpKeepAliveCount: tcpKeepAliveCount,
                suspiciousProcessNames: topSuspects
            )
        )

        var recommendations = recommendationEngine.recommendations(
            drainPerHour: session.drainPerHour,
            darkWakeCount: darkWakeCount,
            tcpKeepAliveCount: tcpKeepAliveCount,
            bluetoothDelayCount: bluetoothDelayCount,
            assertionProcesses: assertionProcesses,
            runningProcessNames: runningNames
        )
        if eventAnalysisStatus.isUnavailable {
            recommendations.insert(eventAnalysisStatus.unavailableRecommendationText, at: 0)
        }

        return SleepReportDraft(
            riskScore: risk.score,
            riskLevel: risk.level,
            summaryText: summary(
                risk: risk.level,
                session: session,
                darkWakeCount: darkWakeCount,
                wakeRequestCount: wakeRequestCount,
                terminatedCount: terminatedApps.count,
                restoredCount: restoredApps.count,
                topSuspects: topSuspects,
                eventAnalysisStatus: eventAnalysisStatus
            ),
            recommendations: recommendations,
            darkWakeCount: darkWakeCount,
            wakeRequestCount: wakeRequestCount,
            assertionCount: assertionEvents.count,
            bluetoothDelayCount: bluetoothDelayCount,
            tcpKeepAliveCount: tcpKeepAliveCount,
            rawPMSetExcerpt: rawPMSetExcerpt,
            topSuspectNames: topSuspects,
            eventAnalysisStatus: eventAnalysisStatus,
            pmsetDiagnostics: pmsetDiagnostics
        )
    }

    private func summary(
        risk: SleepRiskLevel,
        session: SleepSession,
        darkWakeCount: Int,
        wakeRequestCount: Int,
        terminatedCount: Int,
        restoredCount: Int,
        topSuspects: [String],
        eventAnalysisStatus: SleepEventAnalysisStatus
    ) -> String {
        let before = session.batteryBefore
        let after = session.batteryAfter ?? before
        var parts = ["배터리는 \(before)%에서 \(after)%로 \(session.drainPercent)% 감소했습니다."]
        if darkWakeCount > 0 || wakeRequestCount > 0 {
            parts.append("잠자기 중 DarkWake \(darkWakeCount)회, Wake Request \(wakeRequestCount)회가 감지되었습니다.")
        }
        if !topSuspects.isEmpty {
            parts.append("의심 항목은 \(topSuspects.prefix(3).joined(separator: ", "))입니다.")
        }
        if terminatedCount > 0 {
            parts.append("Sleep Guard가 \(terminatedCount)개 앱을 종료했고 \(restoredCount)개 앱을 복구했습니다.")
        }
        if eventAnalysisStatus.isUnavailable {
            parts.append(eventAnalysisStatus.unavailableSummaryText)
        }
        if risk == .good {
            parts.append("현재 수면 상태는 안정적으로 보입니다.")
        }
        return parts.joined(separator: " ")
    }

    private func rankedNames(_ names: [String]) -> [String] {
        let grouped = Dictionary(grouping: names, by: { $0 })
        let counts = grouped.map { key, value in
            (name: key, count: value.count)
        }
        let sorted = counts.sorted { left, right in
            if left.count == right.count {
                return left.name < right.name
            }
            return left.count > right.count
        }
        return sorted.map(\.name)
    }

}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
