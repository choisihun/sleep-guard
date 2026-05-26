import XCTest
@testable import SleepGuard

@MainActor
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

    func testRestorerRejectsNonFileAndOutsideApplicationURLs() async {
        let opener = RecordingApplicationOpener()
        let restorer = SystemAppRestorer(
            opener: opener,
            allowedApplicationDirectories: [URL(fileURLWithPath: "/tmp/AllowedApplications", isDirectory: true)]
        )

        let invalidScheme = RunningAppRecord(
            bundleId: nil,
            displayName: "Invalid",
            appURLString: "https://example.com/App.app",
            pid: 1,
            wasTerminatedBySleepGuard: true
        )
        let outsidePath = RunningAppRecord(
            bundleId: nil,
            displayName: "Outside",
            appURLString: URL(fileURLWithPath: "/tmp/Outside.app").absoluteString,
            pid: 2,
            wasTerminatedBySleepGuard: true
        )

        let invalidSchemeResult = await restorer.restore(record: invalidScheme, shouldRestore: true)
        let outsidePathResult = await restorer.restore(record: outsidePath, shouldRestore: true)

        XCTAssertEqual(invalidSchemeResult, .appURLMissing)
        XCTAssertEqual(outsidePathResult, .appURLMissing)
        XCTAssertTrue(opener.openedURLs.isEmpty)
    }

    func testRestorerOpensValidatedFileApplicationURL() async {
        let opener = RecordingApplicationOpener()
        let allowedDirectory = URL(fileURLWithPath: "/tmp/AllowedApplications", isDirectory: true)
        let appURL = allowedDirectory.appendingPathComponent("Example.app", isDirectory: true)
        let restorer = SystemAppRestorer(
            opener: opener,
            allowedApplicationDirectories: [allowedDirectory]
        )
        let record = RunningAppRecord(
            bundleId: nil,
            displayName: "Example",
            appURLString: appURL.absoluteString,
            pid: 3,
            wasTerminatedBySleepGuard: true
        )

        let result = await restorer.restore(record: record, shouldRestore: true)

        XCTAssertEqual(result, .success)
        XCTAssertEqual(opener.openedURLs, [appURL.standardizedFileURL.resolvingSymlinksInPath()])
    }
}

private final class RecordingApplicationOpener: ApplicationOpening {
    private(set) var openedURLs: [URL] = []

    func openApplication(at url: URL) async -> RestoreResult {
        openedURLs.append(url)
        return .success
    }
}
