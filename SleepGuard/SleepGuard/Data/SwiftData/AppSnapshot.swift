import Foundation
import SwiftData

@Model
final class AppSnapshot {
    var id: UUID
    var sessionId: UUID
    var capturedAt: Date
    var runningAppsJSON: String
    var terminatedAppsJSON: String
    var restoredAppsJSON: String

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        capturedAt: Date = Date(),
        runningAppsJSON: String = "[]",
        terminatedAppsJSON: String = "[]",
        restoredAppsJSON: String = "[]"
    ) {
        self.id = id
        self.sessionId = sessionId
        self.capturedAt = capturedAt
        self.runningAppsJSON = runningAppsJSON
        self.terminatedAppsJSON = terminatedAppsJSON
        self.restoredAppsJSON = restoredAppsJSON
    }
}
