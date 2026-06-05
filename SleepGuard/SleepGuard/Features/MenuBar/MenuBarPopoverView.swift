import SwiftUI

struct MenuBarPopoverView: View {
    @StateObject var viewModel: MenuBarPopoverViewModel
    @ObservedObject private var controller: SleepGuardController

    init(viewModel: MenuBarPopoverViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _controller = ObservedObject(wrappedValue: viewModel.controller)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SleepGuardIcon(size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sleep Guard")
                        .font(.title3.weight(.semibold))
                    Text("수면 보호 상태")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                RiskBadgeView(level: controller.currentRisk.level, score: nil)
            }

            SectionCard(title: nil) {
                VStack(alignment: .leading, spacing: 10) {
                    BatteryStatusView(info: controller.batteryInfo)
                    HStack {
                        Text("전원")
                        Spacer()
                        Text(controller.batteryInfo.powerSource.displayName)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("수면 위험도")
                        Spacer()
                        RiskBadgeView(level: controller.currentRisk.level, score: controller.currentRisk.score)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("의심 앱")
                    .font(.headline)
                if controller.suspiciousApps.isEmpty {
                    Text("현재 배터리 영향이 높은 앱이 없습니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(controller.suspiciousApps.prefix(5)) { app in
                        HStack {
                            Image(systemName: "app.badge")
                                .foregroundStyle(.secondary)
                            Text(app.displayName)
                            Spacer()
                        }
                        .font(.callout)
                    }
                }
            }

            VStack(spacing: 8) {
                PrimaryButton("정리하고 잠자기", systemImage: "moon.zzz.fill") {
                    Task { await viewModel.cleanAndSleep() }
                }
                Button {
                    Task { await viewModel.analyzeNow() }
                } label: {
                    Label("현재 상태 분석", systemImage: "waveform.path.ecg")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                Button {
                    viewModel.openMainWindow()
                } label: {
                    Label("Sleep Guard 열기", systemImage: "macwindow")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
            }

            SectionCard(title: "최근 리포트") {
                if let session = controller.recentSessions.first, let report = controller.recentReports.first(where: { $0.sessionId == session.id }) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(session.batteryBefore)% → \(session.batteryAfter ?? session.batteryBefore)%")
                            .font(.headline)
                        Text(report.eventAnalysisWarningText == nil ? "DarkWake \(report.darkWakeCount)회" : "pmset 이벤트 확인 불가")
                        HStack {
                            Text("판정")
                            RiskBadgeView(level: report.riskLevel, score: report.riskScore)
                        }
                    }
                    .font(.callout)
                } else {
                    Text("아직 생성된 리포트가 없습니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if !controller.lastActionMessage.isEmpty {
                Text(controller.lastActionMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(width: 380)
        .task {
            await controller.refreshCurrentState(updateRisk: false)
        }
    }
}
