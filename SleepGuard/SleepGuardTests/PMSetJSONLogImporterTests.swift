import Foundation
import Testing
@testable import SleepGuard

struct PMSetJSONLogImporterTests {
    @Test func importsRawLinesFromExportedJSON() throws {
        let json = """
        {
          "schemaVersion": 1,
          "entryCount": 2,
          "entries": [
            {"rawLine": "2026-05-22 08:45:58 +0900 Sleep                 Entering Sleep state due to 'Maintenance Sleep':TCPKeepAlive=active Using Batt (Charge:73%)"},
            {"rawLine": "2026-05-22 09:20:45 +0900 DarkWake              DarkWake from Deep Idle [CDNP] : due to NUB.SPMISw3IRQ nub-spmi0.0x02 rtc/SleepService Using BATT (Charge:72%) 2 secs"}
          ]
        }
        """
        let data = try #require(json.data(using: .utf8))
        let importer = PMSetJSONLogImporter()

        let rawLog = try importer.rawLog(from: data)
        let events = try importer.events(from: data)

        #expect(rawLog.contains("Entering Sleep state"))
        #expect(events.contains { $0.category == .sleep && $0.batteryCharge == 73 })
        #expect(events.contains { $0.category == .darkWake && $0.batteryCharge == 72 })
    }
}
