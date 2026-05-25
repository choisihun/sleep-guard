import Foundation
import SwiftData

@MainActor
protocol AppSnapshotStoring {
    func save(snapshot: AppSnapshot) async throws
    func latest(sessionId: UUID) async throws -> AppSnapshot?
}

@MainActor
final class SwiftDataAppSnapshotStore: AppSnapshotStoring {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func save(snapshot: AppSnapshot) async throws {
        context.insert(snapshot)
        try context.save()
    }

    func latest(sessionId: UUID) async throws -> AppSnapshot? {
        var descriptor = FetchDescriptor<AppSnapshot>(
            predicate: #Predicate { $0.sessionId == sessionId },
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
