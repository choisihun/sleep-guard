import Foundation
import SwiftData

@MainActor
final class AppDependencyContainer {
    let modelContainer: ModelContainer
    let modelContext: ModelContext

    let sleepSessionStore: SleepSessionStoring
    let sleepReportStore: SleepReportStoring
    let managedAppStore: ManagedAppStoring
    let settingsStore: SettingsStoring
    let snapshotStore: AppSnapshotStoring

    let controller: SleepGuardController
    let notificationService: UserNotificationServicing
    let loginItemManager: LoginItemManaging

    init(inMemory: Bool = false) throws {
        modelContainer = try SleepGuardSchema.makeModelContainer(inMemory: inMemory)
        modelContext = ModelContext(modelContainer)

        let sleepSessionStore = SwiftDataSleepSessionStore(context: modelContext)
        let sleepReportStore = SwiftDataSleepReportStore(context: modelContext)
        let managedAppStore = SwiftDataManagedAppStore(context: modelContext)
        let settingsStore = SwiftDataSettingsStore(context: modelContext)
        let snapshotStore = SwiftDataAppSnapshotStore(context: modelContext)
        let notificationService = UserNotificationService()
        let protectionConfiguration = try BundleConfigurationLoader.decode(
            AppProtectionConfiguration.self,
            resource: "AppProtectionPolicy"
        )
        let protectionPolicy = ProtectedAppPolicy(configuration: protectionConfiguration)
        let energyImpactScoring = try BundleConfigurationLoader.decode(
            AppEnergyImpactScoring.self,
            resource: "AppEnergyImpactScoring"
        )

        self.sleepSessionStore = sleepSessionStore
        self.sleepReportStore = sleepReportStore
        self.managedAppStore = managedAppStore
        self.settingsStore = settingsStore
        self.snapshotStore = snapshotStore
        self.notificationService = notificationService
        self.loginItemManager = LoginItemManager()

        controller = SleepGuardController(
            batteryMonitor: SystemBatteryMonitor(),
            runningAppProvider: SystemRunningAppProvider(),
            energyImpactProvider: SystemAppEnergyImpactProvider(scoring: energyImpactScoring),
            protectedAppPolicy: protectionPolicy,
            appTerminator: SystemAppTerminator(policy: protectionPolicy),
            appRestorer: SystemAppRestorer(),
            pmsetRunner: PMSetCommandRunner(),
            logParser: PMSetLogParser(),
            reportGenerator: SleepReportGenerator(),
            drainCalculator: BatteryDrainCalculator(),
            sessionStore: sleepSessionStore,
            reportStore: sleepReportStore,
            managedAppStore: managedAppStore,
            settingsStore: settingsStore,
            snapshotStore: snapshotStore,
            notificationService: notificationService
        )
    }
}
