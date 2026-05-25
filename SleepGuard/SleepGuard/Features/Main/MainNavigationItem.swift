import SwiftUI

enum MainNavigationItem: String, CaseIterable, Identifiable {
    case dashboard
    case reports
    case managedApps
    case settings
    case logs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .reports: "Reports"
        case .managedApps: "Managed Apps"
        case .settings: "Settings"
        case .logs: "Logs"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "gauge.with.dots.needle.67percent"
        case .reports: "doc.text.magnifyingglass"
        case .managedApps: "app.connected.to.app.below.fill"
        case .settings: "gearshape"
        case .logs: "terminal"
        }
    }
}
