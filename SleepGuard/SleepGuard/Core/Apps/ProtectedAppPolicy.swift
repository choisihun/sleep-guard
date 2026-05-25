import AppKit
import Foundation

struct AppProtectionConfiguration: Decodable, Equatable {
    var protectedBundleIds: Set<String>
    var protectedProcessNames: Set<String>

    static let empty = AppProtectionConfiguration(
        protectedBundleIds: [],
        protectedProcessNames: []
    )
}

struct ProtectedAppPolicy {
    private let configuration: AppProtectionConfiguration

    init(configuration: AppProtectionConfiguration = .empty) {
        self.configuration = configuration
    }

    func isProtected(_ app: RunningAppInfo) -> Bool {
        if app.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            return true
        }
        if let bundleId = app.bundleId, bundleId == Bundle.main.bundleIdentifier {
            return true
        }
        if let bundleId = app.bundleId, configuration.protectedBundleIds.contains(bundleId) {
            return true
        }
        if configuration.protectedProcessNames.contains(app.displayName) {
            return true
        }
        if app.bundleId == nil {
            return true
        }
        if app.activationPolicy == .prohibited {
            return true
        }
        return false
    }

    func canTerminate(_ app: RunningAppInfo, managedConfiguration: ManagedAppConfiguration?) -> Bool {
        guard let managedConfiguration else { return false }
        return !isProtected(app) &&
            managedConfiguration.isEnabled &&
            managedConfiguration.shouldQuitBeforeSleep &&
            managedConfiguration.bundleId == app.bundleId
    }
}
