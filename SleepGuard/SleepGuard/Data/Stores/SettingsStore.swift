import AppKit
import Foundation
import SwiftData

@MainActor
protocol SettingsStoring {
    func fetchOrCreate() async throws -> AppSettings
    func save(_ settings: AppSettings) async throws
}

@MainActor
final class SwiftDataSettingsStore: SettingsStoring {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchOrCreate() async throws -> AppSettings {
        var descriptor = FetchDescriptor<AppSettings>(sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let settings = AppSettings()
        context.insert(settings)
        try context.save()
        return settings
    }

    func save(_ settings: AppSettings) async throws {
        settings.updatedAt = Date()
        try context.save()
        NSApp.setActivationPolicy(settings.showDockIcon ? .regular : .accessory)
    }
}
