import SwiftUI

struct ReportsListView: View {
    @StateObject var viewModel: ReportsViewModel
    @ObservedObject private var controller: SleepGuardController
    @State private var selectedReportId: UUID?

    init(viewModel: ReportsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _controller = ObservedObject(wrappedValue: viewModel.controller)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedReportId) {
                ForEach(controller.recentReports) { report in
                    let session = controller.recentSessions.first { $0.id == report.sessionId }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(report.generatedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.headline)
                            Spacer()
                            RiskBadgeView(level: report.riskLevel, score: nil)
                        }
                        if let session {
                            Text("\(session.batteryBefore)% → \(session.batteryAfter ?? session.batteryBefore)% · -\(session.drainPercent)% · \(String(format: "%.1f", session.drainPerHour))%/h")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(report.eventAnalysisWarningText == nil ? "DarkWake \(report.darkWakeCount) · Wake Request \(report.wakeRequestCount)" : "pmset 이벤트 확인 불가")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .tag(report.id)
                }
            }
            .navigationTitle("Reports")
            .toolbar {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        } detail: {
            if let selectedReportId,
               let report = controller.recentReports.first(where: { $0.id == selectedReportId }) {
                ReportDetailView(
                    report: report,
                    session: controller.recentSessions.first { $0.id == report.sessionId },
                    isReanalyzing: controller.reanalyzingReportId == report.id,
                    onReanalyze: {
                        Task { await viewModel.reanalyze(reportId: report.id) }
                    }
                )
            } else if let report = controller.recentReports.first {
                ReportDetailView(
                    report: report,
                    session: controller.recentSessions.first { $0.id == report.sessionId },
                    isReanalyzing: controller.reanalyzingReportId == report.id,
                    onReanalyze: {
                        Task { await viewModel.reanalyze(reportId: report.id) }
                    }
                )
            } else {
                EmptyStateView(title: "리포트 없음", message: "Mac이 깨어난 뒤 Sleep Guard가 분석한 결과가 여기에 쌓입니다.", systemImage: "doc.text")
            }
        }
        .task {
            await viewModel.refresh()
        }
    }
}
