import Combine
import SwiftUI

@MainActor
final class MainWindowViewModel: ObservableObject {
    let controller: SleepGuardController
    let managedAppsViewModel: ManagedAppsViewModel
    let settingsViewModel: SettingsViewModel
    let reportsViewModel: ReportsViewModel
    let logsViewModel: LogsViewModel
    let dashboardViewModel: DashboardViewModel

    init(
        controller: SleepGuardController,
        managedAppStore: ManagedAppStoring,
        settingsStore: SettingsStoring,
        loginItemManager: LoginItemManaging,
        openMainWindow: @escaping () -> Void
    ) {
        self.controller = controller
        managedAppsViewModel = ManagedAppsViewModel(controller: controller, store: managedAppStore)
        settingsViewModel = SettingsViewModel(settingsStore: settingsStore, loginItemManager: loginItemManager)
        reportsViewModel = ReportsViewModel(controller: controller)
        logsViewModel = LogsViewModel(controller: controller)
        dashboardViewModel = DashboardViewModel(controller: controller)
    }
}

struct MainWindowView: View {
    @StateObject var viewModel: MainWindowViewModel
    @State private var selection: MainNavigationItem? = .dashboard

    var body: some View {
        NavigationSplitView {
            List(MainNavigationItem.allCases, selection: $selection) { item in
                Label(item.title, systemImage: item.systemImage)
                    .tag(item)
            }
            .navigationTitle("Sleep Guard")
            .frame(minWidth: 190)
        } detail: {
            switch selection ?? .dashboard {
            case .dashboard:
                DashboardView(viewModel: viewModel.dashboardViewModel, selectedItem: $selection)
            case .reports:
                ReportsListView(viewModel: viewModel.reportsViewModel)
            case .managedApps:
                ManagedAppsView(viewModel: viewModel.managedAppsViewModel)
            case .settings:
                SettingsView(viewModel: viewModel.settingsViewModel)
            case .logs:
                LogsView(viewModel: viewModel.logsViewModel)
            }
        }
        .task {
            await viewModel.controller.refreshCurrentState()
            await viewModel.controller.reloadHistory()
        }
    }
}
