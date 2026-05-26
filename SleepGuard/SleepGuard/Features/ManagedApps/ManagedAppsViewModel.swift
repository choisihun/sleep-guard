import Combine
import Foundation

@MainActor
final class ManagedAppsViewModel: ObservableObject {
    @Published private(set) var apps: [ManagedApp] = []
    @Published private(set) var runningApps: [RunningAppInfo] = []
    @Published private(set) var energyRecommendations: [AppEnergyImpact] = []
    @Published var recommendationLimit = 8
    @Published var lastMessage = ""

    let controller: SleepGuardController
    private let store: ManagedAppStoring

    init(controller: SleepGuardController, store: ManagedAppStoring) {
        self.controller = controller
        self.store = store
    }

    func refresh() async {
        apps = (try? await store.fetchAll()) ?? []
        let managedBundleIds = Set(apps.map(\.bundleId))
        runningApps = controller.runningApps.filter { app in
            app.bundleId != nil && controller.canShowInManagedAppRecommendations(app)
        }
        energyRecommendations = controller.appEnergyImpacts.filter { impact in
            guard let bundleId = impact.app.bundleId else { return false }
            return !managedBundleIds.contains(bundleId) &&
                controller.canShowInManagedAppRecommendations(impact.app)
        }
    }

    func addRunningApp(_ app: RunningAppInfo) async {
        do {
            _ = try await store.addFromRunningApp(app)
            await refresh()
            lastMessage = "\(app.displayName)을 관리 앱에 추가했습니다."
        } catch {
            lastMessage = error.localizedDescription
        }
    }

    func addRecommendation(_ impact: AppEnergyImpact) async {
        do {
            guard let managed = try await store.addFromRunningApp(impact.app) else { return }
            managed.isEnabled = true
            managed.shouldQuitBeforeSleep = true
            managed.shouldRestoreAfterWake = true
            managed.riskLevel = impact.level
            managed.category = .unknown
            managed.updatedAt = Date()
            try await store.save()
            await refresh()
            lastMessage = "\(impact.app.displayName)을 배터리 영향 추천에서 추가했습니다."
        } catch {
            lastMessage = error.localizedDescription
        }
    }

    func excludeRecommendation(_ impact: AppEnergyImpact) async {
        do {
            guard let managed = try await store.addFromRunningApp(impact.app) else { return }
            managed.isEnabled = false
            managed.shouldQuitBeforeSleep = false
            managed.shouldRestoreAfterWake = false
            managed.updatedAt = Date()
            try await store.save()
            await refresh()
            lastMessage = "\(impact.app.displayName)을 추천에서 제외했습니다. 등록된 앱에서 다시 켤 수 있습니다."
        } catch {
            lastMessage = error.localizedDescription
        }
    }

    func save(_ app: ManagedApp) async {
        app.updatedAt = Date()
        do {
            try await store.save()
            await refresh()
        } catch {
            lastMessage = error.localizedDescription
        }
    }

    func delete(_ app: ManagedApp) async {
        do {
            try await store.delete(app)
            await refresh()
        } catch {
            lastMessage = error.localizedDescription
        }
    }
}
