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
        let blockingAssertionEvents = sleepBlockingAssertionEvents(assertionEvents)
        let usbCEvents = canAnalyzeEvents ? events.filter(isUSBCEvent) : []
        let bluetoothDelayCount = canAnalyzeEvents ? events.filter {
            $0.category == .bluetooth ||
                $0.rawLine.localizedCaseInsensitiveContains("bluetooth sleep is slow") ||
                $0.rawLine.localizedCaseInsensitiveContains("bluetooth.sleep is slow")
        }.count : 0
        let tcpKeepAliveCount = canAnalyzeEvents ? events.filter(\.isTCPKeepAliveActive).count : 0
        let usbCWakeCount = canAnalyzeEvents ? Set(usbCEvents.map(\.rawLine)).count : 0

        let wakeProcesses = rankedNames(wakeRequestEvents.compactMap(\.processName))
        let assertionProcesses = rankedNames(blockingAssertionEvents.compactMap(\.processName))
        let runningNames = runningApps.map(\.displayName)
        let topSuspects = (wakeProcesses + assertionProcesses).uniqued()

        let risk = analyzer.analyze(
            SleepRiskInput(
                drainPercent: session.drainPercent,
                drainPerHour: session.drainPerHour,
                durationSeconds: session.durationSeconds,
                darkWakeCount: darkWakeCount,
                wakeRequestCount: wakeRequestCount,
                assertionCount: blockingAssertionEvents.count,
                bluetoothDelayCount: bluetoothDelayCount,
                tcpKeepAliveCount: tcpKeepAliveCount,
                usbCWakeCount: usbCWakeCount,
                suspiciousProcessNames: topSuspects
            )
        )

        var recommendations = recommendationEngine.recommendations(
            drainPercent: session.drainPercent,
            drainPerHour: session.drainPerHour,
            durationSeconds: session.durationSeconds,
            darkWakeCount: darkWakeCount,
            tcpKeepAliveCount: tcpKeepAliveCount,
            bluetoothDelayCount: bluetoothDelayCount,
            usbCWakeCount: usbCWakeCount,
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
                tcpKeepAliveCount: tcpKeepAliveCount,
                bluetoothDelayCount: bluetoothDelayCount,
                usbCWakeCount: usbCWakeCount,
                usbCEvents: usbCEvents,
                terminatedCount: terminatedApps.count,
                restoredCount: restoredApps.count,
                topSuspects: topSuspects,
                eventAnalysisStatus: eventAnalysisStatus
            ),
            recommendations: recommendations,
            darkWakeCount: darkWakeCount,
            wakeRequestCount: wakeRequestCount,
            assertionCount: blockingAssertionEvents.count,
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
        tcpKeepAliveCount: Int,
        bluetoothDelayCount: Int,
        usbCWakeCount: Int,
        usbCEvents: [PMSetEvent],
        terminatedCount: Int,
        restoredCount: Int,
        topSuspects: [String],
        eventAnalysisStatus: SleepEventAnalysisStatus
    ) -> String {
        let before = session.batteryBefore
        let after = session.batteryAfter ?? before
        var parts = [
            "\(durationText(session.durationSeconds)) 동안 배터리는 \(before)%에서 \(after)%로 \(session.drainPercent)% 감소했습니다."
        ]
        if let drainContext = drainContext(session) {
            parts.append(drainContext)
        }
        if darkWakeCount > 0 || wakeRequestCount > 0 {
            parts.append("잠자기 중 DarkWake \(darkWakeCount)회, Wake Request \(wakeRequestCount)회가 감지되었습니다.")
        }
        if let dominantCause = dominantDrainCauseText(
            wakeRequestCount: wakeRequestCount,
            tcpKeepAliveCount: tcpKeepAliveCount,
            bluetoothDelayCount: bluetoothDelayCount,
            usbCWakeCount: usbCWakeCount,
            topSuspects: topSuspects
        ) {
            parts.append(dominantCause)
        }
        if usbCWakeCount > 0 {
            parts.append("USB-C/외부 장치 wake 신호 \(usbCWakeCount)회가 감지되었습니다.")
            if let usbCDrainContext = usbCDrainContext(session: session, usbCEvents: usbCEvents) {
                parts.append(usbCDrainContext)
            }
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
        if risk == .good && !eventAnalysisStatus.isUnavailable {
            parts.append("현재 수면 상태는 안정적으로 보입니다.")
        }
        return parts.joined(separator: " ")
    }

    private func drainContext(_ session: SleepSession) -> String? {
        if session.drainPercent >= BatteryDrainThresholds.highTotalDrainPercent {
            if session.drainPerHour <= BatteryDrainThresholds.highDrainPerHour {
                return "시간당 평균은 \(String(format: "%.2f", session.drainPerHour))%/h로 급격하지 않지만, 총 감소량이 커 장시간 누적 방전으로 봐야 합니다."
            }
            return "총 감소량과 시간당 소모가 모두 높은 편입니다."
        }
        if BatteryDrainThresholds.isLongSleepNotableDrain(
            drainPercent: session.drainPercent,
            durationSeconds: session.durationSeconds
        ) {
            return "장시간 수면 기준으로 총 감소량이 큰 편입니다."
        }
        if session.drainPercent >= BatteryDrainThresholds.notableTotalDrainPercent {
            return "총 감소량이 평소보다 큰 편입니다."
        }
        if session.drainPerHour > BatteryDrainThresholds.highDrainPerHour {
            return "시간당 평균 소모가 \(String(format: "%.2f", session.drainPerHour))%/h로 높은 편입니다."
        }
        return nil
    }

    private func dominantDrainCauseText(
        wakeRequestCount: Int,
        tcpKeepAliveCount: Int,
        bluetoothDelayCount: Int,
        usbCWakeCount: Int,
        topSuspects: [String]
    ) -> String? {
        if tcpKeepAliveCount > 0, wakeRequestCount > 20 {
            let names = topSuspects.prefix(3).joined(separator: ", ")
            let usbCContext = usbCWakeCount > 20
                ? " USB-C 신호는 반복 wake 때 같이 잡힌 지연 신호일 가능성이 큽니다."
                : ""
            if names.isEmpty {
                return "가장 큰 반복 원인은 네트워크 유지/TCP KeepAlive 기반 예약 wake로 보입니다.\(usbCContext)"
            }
            return "가장 큰 반복 원인은 네트워크 유지/TCP KeepAlive 기반 예약 wake입니다. 반복 요청자는 \(names)입니다.\(usbCContext)"
        }
        if bluetoothDelayCount > 20 {
            return "가장 큰 반복 원인은 Bluetooth sleep 지연으로 보입니다."
        }
        if usbCWakeCount > 20 {
            return "가장 큰 반복 원인은 USB-C/외부 장치 wake 지연으로 보입니다."
        }
        return nil
    }

    private func usbCDrainContext(session: SleepSession, usbCEvents: [PMSetEvent]) -> String? {
        guard let batteryAfter = session.batteryAfter,
              let firstCharge = usbCEvents
                .sorted(by: { $0.timestamp < $1.timestamp })
                .compactMap(\.batteryCharge)
                .first else {
            return nil
        }

        let drainAfterUSB = max(0, firstCharge - batteryAfter)
        guard drainAfterUSB > 0 else { return nil }

        if session.drainPercent > 0 {
            let share = Int((Double(drainAfterUSB) / Double(session.drainPercent) * 100).rounded())
            return "USB-C 최초 감지 이후 \(drainAfterUSB)%가 더 줄어 전체 감소량의 약 \(share)%와 겹칩니다."
        }
        return "USB-C 최초 감지 이후 \(drainAfterUSB)%가 더 줄었습니다."
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int((seconds / 60).rounded()))
        if minutes < 60 { return "\(minutes)분" }
        return "\(minutes / 60)시간 \(minutes % 60)분"
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

    private func sleepBlockingAssertionEvents(_ events: [PMSetEvent]) -> [PMSetEvent] {
        events.filter { event in
            guard let assertionType = event.assertionType?.lowercased() else { return false }
            let lower = event.rawLine.lowercased()
            guard sleepBlockingAssertionTypes.contains(assertionType) else { return false }
            guard !lower.contains(" released ") else { return false }
            guard !lower.contains(" timedout ") else { return false }
            guard !lower.contains(" turnedoff ") else { return false }
            guard !lower.contains(" summary ") && !lower.contains("summary-") else { return false }
            guard !lower.contains("darkwake") else { return false }
            return true
        }
    }

    private func isUSBCEvent(_ event: PMSetEvent) -> Bool {
        if event.category == .usbC {
            return true
        }
        if containsUSBCSignal(event.rawLine) {
            return true
        }
        return event.wakeReason.map(containsUSBCSignal) ?? false
    }

    private func containsUSBCSignal(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("usb-c")
            || lower.contains("usb_c")
            || lower.contains("usbc")
            || lower.contains("port-usb")
    }
}

private let sleepBlockingAssertionTypes = Set([
    "preventuseridlesystemsleep",
    "preventsystemsleep",
    "internalpreventsleep",
    "noidlesleepassertion",
    "networkclientactive"
])

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
