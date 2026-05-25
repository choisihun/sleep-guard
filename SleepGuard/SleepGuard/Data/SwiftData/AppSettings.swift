import Foundation
import SwiftData

@Model
final class AppSettings {
    var id: UUID
    var launchAtLogin: Bool
    var autoCleanOnWillSleep: Bool
    var showWakeReportNotification: Bool
    var enableForceTerminate: Bool
    var defaultTerminationTimeoutSeconds: Double
    var maxAppsToQuitBeforeSleep: Int?
    var restoreAppsOnWake: Bool
    var includePMSetRawExcerpt: Bool
    var showDockIcon: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        launchAtLogin: Bool = false,
        autoCleanOnWillSleep: Bool = false,
        showWakeReportNotification: Bool = true,
        enableForceTerminate: Bool = false,
        defaultTerminationTimeoutSeconds: Double = 8,
        maxAppsToQuitBeforeSleep: Int? = AppSettingsDefaults.maxAppsToQuitBeforeSleep,
        restoreAppsOnWake: Bool = true,
        includePMSetRawExcerpt: Bool = true,
        showDockIcon: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.launchAtLogin = launchAtLogin
        self.autoCleanOnWillSleep = autoCleanOnWillSleep
        self.showWakeReportNotification = showWakeReportNotification
        self.enableForceTerminate = enableForceTerminate
        self.defaultTerminationTimeoutSeconds = defaultTerminationTimeoutSeconds
        self.maxAppsToQuitBeforeSleep = maxAppsToQuitBeforeSleep
        self.restoreAppsOnWake = restoreAppsOnWake
        self.includePMSetRawExcerpt = includePMSetRawExcerpt
        self.showDockIcon = showDockIcon
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum AppSettingsDefaults {
    static let maxAppsToQuitBeforeSleep = 8
}

extension AppSettings {
    var effectiveMaxAppsToQuitBeforeSleep: Int {
        maxAppsToQuitBeforeSleep ?? AppSettingsDefaults.maxAppsToQuitBeforeSleep
    }
}
