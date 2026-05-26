import AppKit
import Foundation

struct AppProtectionConfiguration: Decodable, Equatable {
    var protectedBundleIds: Set<String>
    var protectedProcessNames: Set<String>
    var forceTerminationAllowedBundleIds: Set<String>

    static let empty = AppProtectionConfiguration(
        protectedBundleIds: [],
        protectedProcessNames: [],
        forceTerminationAllowedBundleIds: []
    )

    init(
        protectedBundleIds: Set<String>,
        protectedProcessNames: Set<String>,
        forceTerminationAllowedBundleIds: Set<String> = []
    ) {
        self.protectedBundleIds = protectedBundleIds
        self.protectedProcessNames = protectedProcessNames
        self.forceTerminationAllowedBundleIds = forceTerminationAllowedBundleIds
    }

    private enum CodingKeys: String, CodingKey {
        case protectedBundleIds
        case protectedProcessNames
        case forceTerminationAllowedBundleIds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        protectedBundleIds = try container.decodeIfPresent(Set<String>.self, forKey: .protectedBundleIds) ?? []
        protectedProcessNames = try container.decodeIfPresent(Set<String>.self, forKey: .protectedProcessNames) ?? []
        forceTerminationAllowedBundleIds = try container.decodeIfPresent(
            Set<String>.self,
            forKey: .forceTerminationAllowedBundleIds
        ) ?? []
    }
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

    func canForceTerminate(_ app: RunningAppInfo, managedConfiguration: ManagedAppConfiguration?) -> Bool {
        guard canTerminate(app, managedConfiguration: managedConfiguration),
              let managedConfiguration,
              let bundleId = app.bundleId else {
            return false
        }
        let forceDeniedCategories: Set<ManagedAppCategory> = [.browser, .development, .document]
        return managedConfiguration.allowsForceTerminate &&
            configuration.forceTerminationAllowedBundleIds.contains(bundleId) &&
            !forceDeniedCategories.contains(managedConfiguration.category)
    }
}
