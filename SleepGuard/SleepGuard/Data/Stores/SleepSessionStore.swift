import Foundation
import SwiftData

@MainActor
protocol SleepSessionStoring {
    func create(startedAt: Date, batteryBefore: Int, wasManualSleep: Bool) async throws -> SleepSession
    func updateAfterWake(_ session: SleepSession, wokeAt: Date, batteryAfter: Int, drain: BatteryDrainResult) async throws
    func fetchRecent(limit: Int) async throws -> [SleepSession]
    func fetch(id: UUID) async throws -> SleepSession?
}

@MainActor
final class SwiftDataSleepSessionStore: SleepSessionStoring {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func create(startedAt: Date, batteryBefore: Int, wasManualSleep: Bool) async throws -> SleepSession {
        let session = SleepSession(sleepStartedAt: startedAt, batteryBefore: batteryBefore, wasManualSleep: wasManualSleep)
        context.insert(session)
        try context.save()
        return session
    }

    func updateAfterWake(_ session: SleepSession, wokeAt: Date, batteryAfter: Int, drain: BatteryDrainResult) async throws {
        session.wokeAt = wokeAt
        session.batteryAfter = batteryAfter
        session.drainPercent = drain.drainPercent
        session.drainPerHour = drain.drainPerHour
        session.durationSeconds = drain.durationSeconds
        try context.save()
    }

    func fetchRecent(limit: Int = 20) async throws -> [SleepSession] {
        var descriptor = FetchDescriptor<SleepSession>(sortBy: [SortDescriptor(\.sleepStartedAt, order: .reverse)])
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func fetch(id: UUID) async throws -> SleepSession? {
        let descriptor = FetchDescriptor<SleepSession>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }
}
