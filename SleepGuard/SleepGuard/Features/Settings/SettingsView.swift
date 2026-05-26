import SwiftUI

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel
    @State private var showsAutoQuitHighImpactWarning = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Settings")
                    .font(.largeTitle.weight(.semibold))

                if let settings = viewModel.settings {
                    SectionCard(title: "동작") {
                        Toggle("로그인 시 실행", isOn: boolBinding(settings, \.launchAtLogin))
                        Toggle("잠자기/덮개 닫힘 자동 정리", isOn: boolBinding(settings, \.autoCleanOnWillSleep))
                        Toggle("배터리 영향 높은 앱 자동 정리", isOn: autoQuitHighImpactBinding(settings))
                        Toggle("깨어난 뒤 앱 복구", isOn: boolBinding(settings, \.restoreAppsOnWake))
                        Toggle("깨어난 뒤 리포트 알림", isOn: boolBinding(settings, \.showWakeReportNotification))
                    }

                    SectionCard(title: "안전 옵션") {
                        Toggle("강제 종료 기능 사용", isOn: boolBinding(settings, \.enableForceTerminate))
                        Toggle("pmset raw 로그 포함", isOn: boolBinding(settings, \.includePMSetRawExcerpt))
                        Stepper(
                            "기본 종료 timeout \(Int(settings.defaultTerminationTimeoutSeconds))초",
                            value: doubleBinding(settings, \.defaultTerminationTimeoutSeconds),
                            in: 2...30,
                            step: 1
                        )
                        Stepper(
                            "잠자기 전 정리 상위 \(settings.effectiveMaxAppsToQuitBeforeSleep)개",
                            value: optionalIntBinding(
                                settings,
                                \.maxAppsToQuitBeforeSleep,
                                fallback: AppSettingsDefaults.maxAppsToQuitBeforeSleep
                            ),
                            in: 1...30,
                            step: 1
                        )
                    }

                    SectionCard(title: "앱 표시") {
                        Toggle("Dock icon 표시", isOn: boolBinding(settings, \.showDockIcon))
                    }
                } else {
                    EmptyStateView(title: "설정 로딩 실패", message: viewModel.message, systemImage: "gearshape")
                        .frame(height: 220)
                }

                if !viewModel.message.isEmpty {
                    Text(viewModel.message)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .navigationTitle("Settings")
        .task {
            await viewModel.load()
        }
        .alert("배터리 영향 높은 앱 자동 정리", isPresented: $showsAutoQuitHighImpactWarning) {
            Button("켜기", role: .destructive) {
                viewModel.settings?.shouldAutoQuitHighImpactAppsBeforeSleep = true
                Task { await viewModel.save() }
            }
            Button("취소", role: .cancel) {
                viewModel.settings?.shouldAutoQuitHighImpactAppsBeforeSleep = false
            }
        } message: {
            Text("관리 앱이 아니어도 배터리 영향이 높은 앱을 잠자기 전에 graceful 종료합니다. 브라우저, 개발 도구, 문서 앱은 자동 정리 대상에서 제외됩니다.")
        }
    }

    private func boolBinding(_ settings: AppSettings, _ keyPath: ReferenceWritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding {
            settings[keyPath: keyPath]
        } set: { value in
            settings[keyPath: keyPath] = value
            Task { await viewModel.save() }
        }
    }

    private func doubleBinding(_ settings: AppSettings, _ keyPath: ReferenceWritableKeyPath<AppSettings, Double>) -> Binding<Double> {
        Binding {
            settings[keyPath: keyPath]
        } set: { value in
            settings[keyPath: keyPath] = value
            Task { await viewModel.save() }
        }
    }

    private func optionalIntBinding(
        _ settings: AppSettings,
        _ keyPath: ReferenceWritableKeyPath<AppSettings, Int?>,
        fallback: Int
    ) -> Binding<Int> {
        Binding {
            settings[keyPath: keyPath] ?? fallback
        } set: { value in
            settings[keyPath: keyPath] = value
            Task { await viewModel.save() }
        }
    }

    private func autoQuitHighImpactBinding(_ settings: AppSettings) -> Binding<Bool> {
        Binding {
            settings.shouldAutoQuitHighImpactAppsBeforeSleep
        } set: { value in
            if value {
                showsAutoQuitHighImpactWarning = true
            } else {
                settings.shouldAutoQuitHighImpactAppsBeforeSleep = false
                Task { await viewModel.save() }
            }
        }
    }
}
