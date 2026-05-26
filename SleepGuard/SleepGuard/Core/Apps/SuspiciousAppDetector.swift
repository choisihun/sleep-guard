import Foundation

struct SuspiciousAppDetector {
    private let policy: ProtectedAppPolicy

    init(policy: ProtectedAppPolicy = ProtectedAppPolicy()) {
        self.policy = policy
    }

    func suspiciousApps(
        runningApps: [RunningAppInfo],
        managedApps: [ManagedApp],
        energyImpacts: [AppEnergyImpact] = []
    ) -> [RunningAppInfo] {
        let enabledManagedBundleIds = Set(managedApps.filter(\.isEnabled).map(\.bundleId))
        let runningByBundleId = Dictionary(
            runningApps.compactMap { app -> (String, RunningAppInfo)? in
                guard let bundleId = app.bundleId, !policy.isProtected(app) else { return nil }
                return (bundleId, app)
            },
            uniquingKeysWith: { first, _ in first }
        )
        let highImpactApps = energyImpacts
            .filter { $0.level == .high && !policy.isProtected($0.app) }
            .sorted {
                if $0.score == $1.score {
                    return $0.app.displayName.localizedCaseInsensitiveCompare($1.app.displayName) == .orderedAscending
                }
                return $0.score > $1.score
            }

        var result: [RunningAppInfo] = highImpactApps.map(\.app)
        var seenBundleIds = Set(result.compactMap(\.bundleId))

        for bundleId in enabledManagedBundleIds.sorted() {
            guard !seenBundleIds.contains(bundleId), let app = runningByBundleId[bundleId] else {
                continue
            }
            result.append(app)
            seenBundleIds.insert(bundleId)
        }
        return result
    }
}
