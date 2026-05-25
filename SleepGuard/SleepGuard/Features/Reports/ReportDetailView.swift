import SwiftUI

struct ReportDetailView: View {
    var report: SleepReport
    var session: SleepSession?
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
                    MetricRow(title: "DarkWake", value: "\(report.darkWakeCount)")
                    MetricRow(title: "Wake Requests", value: "\(report.wakeRequestCount)")
                    MetricRow(title: "Assertions", value: "\(report.assertionCount)")
                    MetricRow(title: "Bluetooth Delay", value: "\(report.bluetoothDelayCount)")
                    MetricRow(title: "TCP KeepAlive", value: "\(report.tcpKeepAliveCount)")
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
                        Text(report.rawPMSetExcerpt.isEmpty ? "raw log excerpt disabled" : report.rawPMSetExcerpt)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 180)
                }
            }
            .padding(24)
        }
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes)분" }
        return "\(minutes / 60)시간 \(minutes % 60)분"
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
