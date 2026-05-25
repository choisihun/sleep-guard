import Foundation
import SwiftData

@MainActor
protocol ManagedAppStoring {
    func fetchAll() async throws -> [ManagedApp]
    func fetchEnabled() async throws -> [ManagedApp]
    func fetch(bundleId: String) async throws -> ManagedApp?
    func addFromRunningApp(_ app: RunningAppInfo) async throws -> ManagedApp?
    func save() async throws
    func delete(_ app: ManagedApp) async throws
}

@MainActor
final class SwiftDataManagedAppStore: ManagedAppStoring {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() async throws -> [ManagedApp] {
        let descriptor = FetchDescriptor<ManagedApp>(sortBy: [SortDescriptor(\.displayName)])
        return try context.fetch(descriptor)
    }

    func fetchEnabled() async throws -> [ManagedApp] {
        let descriptor = FetchDescriptor<ManagedApp>(
            predicate: #Predicate { $0.isEnabled == true },
            sortBy: [SortDescriptor(\.displayName)]
        )
        return try context.fetch(descriptor)
    }

    func fetch(bundleId: String) async throws -> ManagedApp? {
        let descriptor = FetchDescriptor<ManagedApp>(predicate: #Predicate { $0.bundleId == bundleId })
        return try context.fetch(descriptor).first
    }

    func addFromRunningApp(_ app: RunningAppInfo) async throws -> ManagedApp? {
        guard let bundleId = app.bundleId else { return nil }
        if let existing = try await fetch(bundleId: bundleId) {
            return existing
        }
        let managed = ManagedApp(
            bundleId: bundleId,
            displayName: app.displayName,
            appURLString: app.bundleURL?.absoluteString ?? app.executableURL?.absoluteString,
            isEnabled: true,
            categoryRawValue: inferredCategory(for: app).rawValue,
            riskLevelRawValue: inferredRisk(for: app).rawValue
        )
        context.insert(managed)
        try context.save()
        return managed
    }

    func save() async throws {
        try context.save()
    }

    func delete(_ app: ManagedApp) async throws {
        context.delete(app)
        try context.save()
    }

    private func inferredCategory(for app: RunningAppInfo) -> ManagedAppCategory {
        _ = app
        return .unknown
    }

    private func inferredRisk(for app: RunningAppInfo) -> ManagedAppRiskLevel {
        _ = app
        return .medium
    }
}
