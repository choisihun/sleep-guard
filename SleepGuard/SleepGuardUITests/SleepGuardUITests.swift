import XCTest

final class SleepGuardUITests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launchEnvironment["SLEEP_GUARD_UI_TESTING"] = "1"
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5) || app.wait(for: .runningBackground, timeout: 5))
        app.terminate()
    }
}
