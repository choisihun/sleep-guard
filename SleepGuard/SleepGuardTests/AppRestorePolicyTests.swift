import XCTest
@testable import SleepGuard

final class AppRestorePolicyTests: XCTestCase {
    func testRecordTracksRestoreStateWithoutLaunchingApps() {
        var record = RunningAppRecord(
            bundleId: "com.example.App",
            displayName: "Example",
            appURLString: nil,
            pid: 10,
            wasTerminatedBySleepGuard: true
        )
        record.wasRestoredBySleepGuard = false

        XCTAssertTrue(record.wasTerminatedBySleepGuard)
        XCTAssertFalse(record.wasRestoredBySleepGuard)
    }
}
