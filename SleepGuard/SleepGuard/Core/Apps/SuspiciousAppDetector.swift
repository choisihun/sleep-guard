import Foundation

struct SuspiciousAppDetector {
    private let policy: ProtectedAppPolicy

    init(policy: ProtectedAppPolicy = ProtectedAppPolicy()) {
        self.policy = policy
    }

    func suspiciousApps(runningApps: [RunningAppInfo], managedApps: [ManagedApp]) -> [RunningAppInfo] {
        let enabledManagedBundleIds = Set(managedApps.filter(\.isEnabled).map(\.bundleId))
        return runningApps.filter { app in
            guard !policy.isProtected(app) else { return false }
            if let bundleId = app.bundleId, enabledManagedBundleIds.contains(bundleId) {
                return true
            }
            return false
        }
    }
}
