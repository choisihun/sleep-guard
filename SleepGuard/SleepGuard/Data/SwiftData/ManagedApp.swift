import Foundation
import SwiftData

@Model
final class ManagedApp {
    var id: UUID
    var bundleId: String
    var displayName: String
    var appURLString: String?
    var isEnabled: Bool
    var shouldQuitBeforeSleep: Bool
    var shouldRestoreAfterWake: Bool
    var allowsForceTerminate: Bool
    var terminationTimeoutSeconds: Double
    var categoryRawValue: String
    var riskLevelRawValue: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        bundleId: String,
        displayName: String,
        appURLString: String? = nil,
        isEnabled: Bool = false,
        shouldQuitBeforeSleep: Bool = true,
        shouldRestoreAfterWake: Bool = true,
        allowsForceTerminate: Bool = false,
        terminationTimeoutSeconds: Double = 8,
        categoryRawValue: String = ManagedAppCategory.unknown.rawValue,
        riskLevelRawValue: String = ManagedAppRiskLevel.medium.rawValue,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.bundleId = bundleId
        self.displayName = displayName
        self.appURLString = appURLString
        self.isEnabled = isEnabled
        self.shouldQuitBeforeSleep = shouldQuitBeforeSleep
        self.shouldRestoreAfterWake = shouldRestoreAfterWake
        self.allowsForceTerminate = allowsForceTerminate
        self.terminationTimeoutSeconds = terminationTimeoutSeconds
        self.categoryRawValue = categoryRawValue
        self.riskLevelRawValue = riskLevelRawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var category: ManagedAppCategory {
        get { ManagedAppCategory(rawValue: categoryRawValue) ?? .unknown }
        set {
            categoryRawValue = newValue.rawValue
            updatedAt = Date()
        }
    }

    var riskLevel: ManagedAppRiskLevel {
        get { ManagedAppRiskLevel(rawValue: riskLevelRawValue) ?? .medium }
        set {
            riskLevelRawValue = newValue.rawValue
            updatedAt = Date()
        }
    }

    var configuration: ManagedAppConfiguration {
        ManagedAppConfiguration(
            id: id,
            bundleId: bundleId,
            displayName: displayName,
            appURLString: appURLString,
            isEnabled: isEnabled,
            shouldQuitBeforeSleep: shouldQuitBeforeSleep,
            shouldRestoreAfterWake: shouldRestoreAfterWake,
            allowsForceTerminate: allowsForceTerminate,
            terminationTimeoutSeconds: terminationTimeoutSeconds,
            category: category,
            riskLevel: riskLevel
        )
    }
}
