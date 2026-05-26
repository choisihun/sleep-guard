import SwiftUI

struct ManagedAppsView: View {
    @StateObject var viewModel: ManagedAppsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Managed Apps")
                    .font(.largeTitle.weight(.semibold))

                AppPickerView(viewModel: viewModel)

                SectionCard(title: "등록된 앱") {
                    if viewModel.apps.isEmpty {
                        EmptyStateView(title: "관리 앱 없음", message: "배터리 영향 상위 앱에서 종료 허용 앱을 추가하세요.", systemImage: "app.badge")
                            .frame(height: 180)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(viewModel.apps) { app in
                                ManagedAppRow(app: app, viewModel: viewModel)
                                Divider()
                            }
                        }
                    }
                }

                if !viewModel.lastMessage.isEmpty {
                    Text(viewModel.lastMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .navigationTitle("Managed Apps")
        .task {
            await viewModel.controller.refreshCurrentState()
            await viewModel.refresh()
        }
    }
}

private struct ManagedAppRow: View {
    @Bindable var app: ManagedApp
    let viewModel: ManagedAppsViewModel
    @State private var showsForceTerminateWarning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading) {
                    Text(app.displayName)
                        .font(.headline)
                    Text(app.bundleId)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Enabled", isOn: binding(\.isEnabled))
                    .toggleStyle(.switch)
                Button(role: .destructive) {
                    Task { await viewModel.delete(app) }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Toggle("잠자기 전 종료", isOn: binding(\.shouldQuitBeforeSleep))
                    Toggle("깨어난 후 다시 실행", isOn: binding(\.shouldRestoreAfterWake))
                }
                GridRow {
                    Toggle("강제 종료 허용", isOn: forceTerminateBinding)
                    HStack {
                        Text("종료 대기")
                        Stepper("\(Int(app.terminationTimeoutSeconds))초", value: timeoutBinding, in: 2...30, step: 1)
                    }
                }
                GridRow {
                    Picker("Category", selection: categoryBinding) {
                        ForEach(ManagedAppCategory.allCases) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    Picker("Risk", selection: riskBinding) {
                        ForEach(ManagedAppRiskLevel.allCases) { risk in
                            Text(risk.displayName).tag(risk)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .alert("강제 종료 허용", isPresented: $showsForceTerminateWarning) {
            Button("허용", role: .destructive) {
                app.allowsForceTerminate = true
                Task { await viewModel.save(app) }
            }
            Button("취소", role: .cancel) {
                app.allowsForceTerminate = false
            }
        } message: {
            Text("저장되지 않은 작업이 손실될 수 있습니다. 전역 설정과 보호 정책 allowlist가 모두 허용할 때만 실제 강제 종료가 실행됩니다.")
        }
    }

    private func binding(_ keyPath: ReferenceWritableKeyPath<ManagedApp, Bool>) -> Binding<Bool> {
        Binding {
            app[keyPath: keyPath]
        } set: { newValue in
            app[keyPath: keyPath] = newValue
            Task { await viewModel.save(app) }
        }
    }

    private var timeoutBinding: Binding<Double> {
        Binding {
            app.terminationTimeoutSeconds
        } set: { newValue in
            app.terminationTimeoutSeconds = newValue
            Task { await viewModel.save(app) }
        }
    }

    private var forceTerminateBinding: Binding<Bool> {
        Binding {
            app.allowsForceTerminate
        } set: { newValue in
            if newValue {
                showsForceTerminateWarning = true
            } else {
                app.allowsForceTerminate = false
                Task { await viewModel.save(app) }
            }
        }
    }

    private var categoryBinding: Binding<ManagedAppCategory> {
        Binding {
            app.category
        } set: { newValue in
            app.category = newValue
            Task { await viewModel.save(app) }
        }
    }

    private var riskBinding: Binding<ManagedAppRiskLevel> {
        Binding {
            app.riskLevel
        } set: { newValue in
            app.riskLevel = newValue
            Task { await viewModel.save(app) }
        }
    }
}
