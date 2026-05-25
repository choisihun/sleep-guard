import Foundation
import XCTest
@testable import SleepGuard

final class ExternalLogJSONParserTests: XCTestCase {
    func testParsesExternalLogJSONWhenProvided() throws {
        let fallbackPath = "/Users/choesihun/Desktop/DevelopingFolder/swift/log.json"
        let path = ProcessInfo.processInfo.environment["SLEEP_GUARD_LOG_JSON"] ?? fallbackPath
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("Set SLEEP_GUARD_LOG_JSON to test a local exported log.json file.")
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let rawLog = try PMSetJSONLogImporter().rawLog(from: data)
        let entries = rawLog.split(separator: "\n")
        let events = try PMSetJSONLogImporter().events(from: data)
        let darkWakeCount = events.filter { $0.category == .darkWake }.count
        let assertionCount = events.filter { $0.category == .assertion }.count
        let wakeRequestCount = events.filter { $0.category == .wakeRequest }.count
        let bluetoothDelayCount = events.filter {
            $0.rawLine.localizedCaseInsensitiveContains("bluetooth.sleep is slow") ||
                $0.rawLine.localizedCaseInsensitiveContains("bluetooth sleep is slow")
        }.count

        XCTAssertGreaterThan(entries.count, 1_000)
        XCTAssertGreaterThanOrEqual(events.count, entries.count)
        XCTAssertGreaterThan(darkWakeCount, 0)
        XCTAssertGreaterThan(assertionCount, 0)
        XCTAssertGreaterThan(wakeRequestCount, 0)
        XCTAssertGreaterThan(bluetoothDelayCount, 0)
        XCTAssertTrue(events.contains { $0.category == .sleepService })
    }
}
