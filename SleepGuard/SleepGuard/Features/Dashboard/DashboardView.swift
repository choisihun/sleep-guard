import SwiftUI

struct DashboardView: View {
    @StateObject var viewModel: DashboardViewModel
    @ObservedObject private var controller: SleepGuardController
    @Binding var selectedItem: MainNavigationItem?

    init(viewModel: DashboardViewModel, selectedItem: Binding<MainNavigationItem?>) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _controller = ObservedObject(wrappedValue: viewModel.controller)
        _selectedItem = selectedItem
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Dashboard")
                            .font(.largeTitle.weight(.semibold))
                        Text("잠들기 전 위험 요소와 최근 수면 결과를 확인합니다.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    RiskBadgeView(level: controller.currentRisk.level, score: controller.currentRisk.score)
                }

                HStack(alignment: .top, spacing: 14) {
                    SectionCard(title: "현재 배터리") {
                        BatteryStatusView(info: controller.batteryInfo)
                        Text("측정 시각 \(controller.batteryInfo.timestamp.formatted(date: .omitted, time: .standard))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    SectionCard(title: "전원 상태") {
                        Label(controller.batteryInfo.powerSource.displayName, systemImage: controller.batteryInfo.powerSource == .ac ? "powerplug" : "battery.75percent")
                            .font(.headline)
                        Text(controller.batteryInfo.isCharging ? "충전 중" : "충전 중 아님")
                            .foregroundStyle(.secondary)
                    }
                    SectionCard(title: "Sleep Risk") {
                        RiskBadgeView(level: controller.currentRisk.level, score: controller.currentRisk.score)
                        Text(controller.assertionSummary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                SectionCard(title: "빠른 액션") {
                    HStack(spacing: 10) {
                        Button {
                            Task { await viewModel.cleanAndSleep() }
                        } label: {
                            Label("정리하고 잠자기", systemImage: "moon.zzz.fill")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            Task { await viewModel.analyzeNow() }
                        } label: {
                            Label("현재 상태 분석", systemImage: "waveform.path.ecg")
                        }

                        Button {
                            selectedItem = .managedApps
                        } label: {
                            Label("앱 관리 열기", systemImage: "app.badge")
                        }

                        Button {
                            selectedItem = .reports
                        } label: {
                            Label("최근 리포트 열기", systemImage: "doc.text.magnifyingglass")
                        }
                    }
                }

                HStack(alignment: .top, spacing: 14) {
                    SectionCard(title: "현재 실행 중인 위험 앱") {
                        if controller.suspiciousApps.isEmpty {
                            Text("관리 대상 중 현재 종료 대상 앱이 없습니다.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(controller.suspiciousApps) { app in
                                HStack {
                                    Image(systemName: "app.badge")
                                    VStack(alignment: .leading) {
                                        Text(app.displayName)
                                        Text(app.bundleId ?? "bundle id 없음")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }

                    SectionCard(title: "최근 수면 리포트") {
                        if let report = controller.recentReports.first,
                           let session = controller.recentSessions.first(where: { $0.id == report.sessionId }) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(session.sleepStartedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.headline)
                                    Spacer()
                                    RiskBadgeView(level: report.riskLevel, score: report.riskScore)
                                }
                                Text("\(session.batteryBefore)% → \(session.batteryAfter ?? session.batteryBefore)% · DarkWake \(report.darkWakeCount)회")
                                    .foregroundStyle(.secondary)
                                Text(report.summaryText)
                                    .lineLimit(4)
                            }
                        } else {
                            Text("리포트가 생성되면 여기에 표시됩니다.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !controller.lastActionMessage.isEmpty {
                    Text(controller.lastActionMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .navigationTitle("Dashboard")
    }
}
