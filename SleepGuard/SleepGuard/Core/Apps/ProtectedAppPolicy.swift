import AppKit
import Foundation

struct AppProtectionConfiguration: Decodable, Equatable {
    var protectedBundleIds: Set<String>
    var protectedProcessNames: Set<String>
    var forceTerminationAllowedBundleIds: Set<String>
    var autoTerminationDeniedBundleIds: Set<String>
    var autoTerminationDeniedProcessNames: Set<String>
    var autoTerminationDeniedBundleIdPrefixes: Set<String>

    static let empty = AppProtectionConfiguration(
        protectedBundleIds: [],
        protectedProcessNames: [],
        forceTerminationAllowedBundleIds: [],
        autoTerminationDeniedBundleIds: [],
        autoTerminationDeniedProcessNames: [],
        autoTerminationDeniedBundleIdPrefixes: []
    )

    init(
        protectedBundleIds: Set<String>,
        protectedProcessNames: Set<String>,
        forceTerminationAllowedBundleIds: Set<String> = [],
        autoTerminationDeniedBundleIds: Set<String> = [],
        autoTerminationDeniedProcessNames: Set<String> = [],
        autoTerminationDeniedBundleIdPrefixes: Set<String> = []
    ) {
        self.protectedBundleIds = protectedBundleIds
        self.protectedProcessNames = protectedProcessNames
        self.forceTerminationAllowedBundleIds = forceTerminationAllowedBundleIds
        self.autoTerminationDeniedBundleIds = autoTerminationDeniedBundleIds
        self.autoTerminationDeniedProcessNames = autoTerminationDeniedProcessNames
        self.autoTerminationDeniedBundleIdPrefixes = autoTerminationDeniedBundleIdPrefixes
    }

    private enum CodingKeys: String, CodingKey {
        case protectedBundleIds
        case protectedProcessNames
        case forceTerminationAllowedBundleIds
        case autoTerminationDeniedBundleIds
        case autoTerminationDeniedProcessNames
        case autoTerminationDeniedBundleIdPrefixes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        protectedBundleIds = try container.decodeIfPresent(Set<String>.self, forKey: .protectedBundleIds) ?? []
        protectedProcessNames = try container.decodeIfPresent(Set<String>.self, forKey: .protectedProcessNames) ?? []
        forceTerminationAllowedBundleIds = try container.decodeIfPresent(
            Set<String>.self,
            forKey: .forceTerminationAllowedBundleIds
        ) ?? []
        autoTerminationDeniedBundleIds = try container.decodeIfPresent(
            Set<String>.self,
            forKey: .autoTerminationDeniedBundleIds
        ) ?? []
        autoTerminationDeniedProcessNames = try container.decodeIfPresent(
            Set<String>.self,
            forKey: .autoTerminationDeniedProcessNames
        ) ?? []
        autoTerminationDeniedBundleIdPrefixes = try container.decodeIfPresent(
            Set<String>.self,
            forKey: .autoTerminationDeniedBundleIdPrefixes
        ) ?? []
    }
}

struct ProtectedAppPolicy {
    private let configuration: AppProtectionConfiguration
    private let builtInAutoTerminationDeniedBundleIds: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "org.mozilla.firefox",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "company.thebrowser.Browser",
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi",
        "org.chromium.Chromium",
        "com.apple.dt.Xcode",
        "com.microsoft.VSCode",
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.apple.TextEdit",
        "com.apple.Preview",
        "com.apple.iWork.Pages",
        "com.apple.iWork.Numbers",
        "com.apple.iWork.Keynote",
        "com.microsoft.Word",
        "com.microsoft.Excel",
        "com.microsoft.Powerpoint",
        "com.figma.Desktop",
        "notion.id",
        "md.obsidian"
    ]
    private let builtInAutoTerminationDeniedBundleIdPrefixes: Set<String> = [
        "com.jetbrains.",
        "com.adobe."
    ]
    private let builtInAutoTerminationDeniedProcessNames: Set<String> = [
        "Safari",
        "Google Chrome",
        "Chrome",
        "Firefox",
        "Microsoft Edge",
        "Brave Browser",
        "Arc",
        "Opera",
        "Vivaldi",
        "Chromium",
        "Xcode",
        "Visual Studio Code",
        "Cursor",
        "Terminal",
        "iTerm2",
        "TextEdit",
        "Preview",
        "Pages",
        "Numbers",
        "Keynote",
        "Microsoft Word",
        "Microsoft Excel",
        "Microsoft PowerPoint",
        "Figma",
        "Notion",
        "Obsidian"
    ]

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

    func canAutoTerminateHighImpactApp(_ app: RunningAppInfo) -> Bool {
        guard !isProtected(app), let bundleId = app.bundleId else { return false }
        let deniedBundleIds = builtInAutoTerminationDeniedBundleIds.union(configuration.autoTerminationDeniedBundleIds)
        if deniedBundleIds.contains(bundleId) {
            return false
        }

        let deniedPrefixes = builtInAutoTerminationDeniedBundleIdPrefixes
            .union(configuration.autoTerminationDeniedBundleIdPrefixes)
        if deniedPrefixes.contains(where: { bundleId.hasPrefix($0) }) {
            return false
        }

        let deniedProcessNames = builtInAutoTerminationDeniedProcessNames.union(configuration.autoTerminationDeniedProcessNames)
        if deniedProcessNames.contains(app.displayName) {
            return false
        }

        return true
    }
}
