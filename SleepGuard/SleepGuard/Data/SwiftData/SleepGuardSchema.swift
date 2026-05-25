import Foundation
import SwiftData

enum SleepGuardSchema {
    static var schema: Schema {
        Schema([
            SleepSession.self,
            SleepReport.self,
            ManagedApp.self,
            AppSnapshot.self,
            AppSettings.self
        ])
    }

    static func makeModelContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
