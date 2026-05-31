import Foundation
import SwiftData

@Model
final class AppSettings {
    var id: UUID
    var launchAtLogin: Bool
    var autoCleanOnWillSleep: Bool
    var didShowLaunchAtLoginPrompt: Bool?
    var autoQuitHighImpactAppsBeforeSleep: Bool?
    var showWakeReportNotification: Bool
    var enableForceTerminate: Bool
    var defaultTerminationTimeoutSeconds: Double
    var maxAppsToQuitBeforeSleep: Int?
    var restoreAppsOnWake: Bool
    var includePMSetRawExcerpt: Bool
    var showDockIcon: Bool
    var batterySleepOptimizationEnabled: Bool?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        launchAtLogin: Bool = false,
        autoCleanOnWillSleep: Bool = true,
        didShowLaunchAtLoginPrompt: Bool = false,
        autoQuitHighImpactAppsBeforeSleep: Bool = false,
        showWakeReportNotification: Bool = true,
        enableForceTerminate: Bool = false,
        defaultTerminationTimeoutSeconds: Double = 8,
        maxAppsToQuitBeforeSleep: Int? = AppSettingsDefaults.maxAppsToQuitBeforeSleep,
        restoreAppsOnWake: Bool = true,
        includePMSetRawExcerpt: Bool = true,
        showDockIcon: Bool = false,
        batterySleepOptimizationEnabled: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.launchAtLogin = launchAtLogin
        self.autoCleanOnWillSleep = autoCleanOnWillSleep
        self.didShowLaunchAtLoginPrompt = didShowLaunchAtLoginPrompt
        self.autoQuitHighImpactAppsBeforeSleep = autoQuitHighImpactAppsBeforeSleep
        self.showWakeReportNotification = showWakeReportNotification
        self.enableForceTerminate = enableForceTerminate
        self.defaultTerminationTimeoutSeconds = defaultTerminationTimeoutSeconds
        self.maxAppsToQuitBeforeSleep = maxAppsToQuitBeforeSleep
        self.restoreAppsOnWake = restoreAppsOnWake
        self.includePMSetRawExcerpt = includePMSetRawExcerpt
        self.showDockIcon = showDockIcon
        self.batterySleepOptimizationEnabled = batterySleepOptimizationEnabled
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

    var shouldAutoQuitHighImpactAppsBeforeSleep: Bool {
        get { autoQuitHighImpactAppsBeforeSleep ?? false }
        set { autoQuitHighImpactAppsBeforeSleep = newValue }
    }

    var hasShownLaunchAtLoginPrompt: Bool {
        get { didShowLaunchAtLoginPrompt ?? false }
        set { didShowLaunchAtLoginPrompt = newValue }
    }

    var shouldApplyBatterySleepOptimization: Bool {
        get { batterySleepOptimizationEnabled ?? false }
        set { batterySleepOptimizationEnabled = newValue }
    }
}
