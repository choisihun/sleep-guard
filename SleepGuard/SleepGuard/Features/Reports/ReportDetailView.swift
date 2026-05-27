import SwiftUI

struct ReportDetailView: View {
    var report: SleepReport
    var session: SleepSession?
    var isReanalyzing = false
    var onReanalyze: () -> Void = {}
    @State private var showRawLog = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Report Detail")
                            .font(.largeTitle.weight(.semibold))
                        Text(report.generatedAt.formatted(date: .complete, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        onReanalyze()
                    } label: {
                        Label(isReanalyzing ? "분석 중" : "다시 분석", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(!canReanalyze || isReanalyzing)
                    RiskBadgeView(level: report.riskLevel, score: report.riskScore)
                }

                if let session {
                    SectionCard(title: "수면 세션") {
                        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                            GridRow {
                                Text("시작")
                                Text(session.sleepStartedAt.formatted(date: .abbreviated, time: .standard))
                            }
                            GridRow {
                                Text("종료")
                                Text(session.wokeAt?.formatted(date: .abbreviated, time: .standard) ?? "기록 없음")
                            }
                            GridRow {
                                Text("Duration")
                                Text(durationText(session.durationSeconds))
                            }
                            GridRow {
                                Text("배터리")
                                Text("\(session.batteryBefore)% → \(session.batteryAfter ?? session.batteryBefore)%")
                            }
                            GridRow {
                                Text("Drain")
                                Text("-\(session.drainPercent)% · \(String(format: "%.2f", session.drainPerHour))%/h")
                            }
                        }
                    }
                }

                SectionCard(title: "분석") {
                    if let eventAnalysisWarningText = report.eventAnalysisWarningText {
                        Label(eventAnalysisWarningText, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    }
                    MetricRow(title: "DarkWake", value: metricValue(report.darkWakeCount))
                    MetricRow(title: "Wake Requests", value: metricValue(report.wakeRequestCount))
                    MetricRow(title: "Assertions", value: metricValue(report.assertionCount))
                    MetricRow(title: "Bluetooth Delay", value: metricValue(report.bluetoothDelayCount))
                    MetricRow(title: "TCP KeepAlive", value: metricValue(report.tcpKeepAliveCount))
                }

                SectionCard(title: "pmset 수집 진단") {
                    if let diagnostics = report.pmsetDiagnostics {
                        MetricRow(title: "수집 시각", value: diagnostics.collectedAt?.formatted(date: .abbreviated, time: .standard) ?? "기록 없음")
                        MetricRow(title: "재시도", value: "\(diagnostics.retryCount)회")
                        MetricRow(title: "세션 이벤트 라인", value: "\(diagnostics.sessionEventLineCount)")
                        MetricRow(title: "raw 로그 라인", value: "\(diagnostics.rawLogLineCount)")
                        MetricRow(title: "분석 윈도우", value: analysisWindowText(diagnostics))
                        if let error = diagnostics.errorDescription, !error.isEmpty {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    } else {
                        Text("이 리포트에는 pmset 수집 진단값이 없습니다.")
                            .foregroundStyle(.secondary)
                    }
                }

                SectionCard(title: "요약") {
                    Text(report.summaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SectionCard(title: "의심 프로세스") {
                    if report.topSuspectNames.isEmpty {
                        Text("두드러진 의심 프로세스가 없습니다.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(report.topSuspectNames, id: \.self) { name in
                            Label(name, systemImage: "exclamationmark.triangle")
                        }
                    }
                }

                SectionCard(title: "추천 조치") {
                    ForEach(report.recommendationTexts, id: \.self) { recommendation in
                        Label(recommendation, systemImage: "checkmark.circle")
                    }
                }

                DisclosureGroup("raw pmset excerpt", isExpanded: $showRawLog) {
                    ScrollView(.horizontal) {
                        Text(rawLogText)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 180)
                }
            }
            .frame(maxWidth: 820, alignment: .leading)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes)분" }
        return "\(minutes / 60)시간 \(minutes % 60)분"
    }

    private func metricValue(_ count: Int) -> String {
        report.eventAnalysisWarningText == nil ? "\(count)" : "확인 불가"
    }

    private var canReanalyze: Bool {
        session?.wokeAt != nil
    }

    private var rawLogText: String {
        if let eventAnalysisWarningText = report.eventAnalysisWarningText {
            return eventAnalysisWarningText
        }
        return report.rawPMSetExcerpt.isEmpty ? "raw log excerpt disabled" : report.rawPMSetExcerpt
    }

    private func analysisWindowText(_ diagnostics: PMSetLogDiagnostics) -> String {
        guard let start = diagnostics.analysisWindowStart,
              let end = diagnostics.analysisWindowEnd else {
            return "전체 로그"
        }
        return "\(start.formatted(date: .omitted, time: .standard)) ~ \(end.formatted(date: .omitted, time: .standard))"
    }
}

private struct MetricRow: View {
    var title: String
    var value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.headline)
        }
    }
}
