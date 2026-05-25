import AppKit
import XCTest
@testable import SleepGuard

final class AppTerminatorPolicyTests: XCTestCase {
    func testProtectsSystemAndUnmanagedApps() {
        let policy = ProtectedAppPolicy(
            configuration: AppProtectionConfiguration(
                protectedBundleIds: ["com.apple.finder"],
                protectedProcessNames: ["Finder"]
            )
        )
        let finder = RunningAppInfo(
            bundleId: "com.apple.finder",
            displayName: "Finder",
            executableURL: nil,
            bundleURL: nil,
            processIdentifier: 100,
            activationPolicyRawValue: NSApplication.ActivationPolicy.regular.rawValue,
            isTerminated: false,
            isHidden: false
        )
        let chrome = RunningAppInfo(
            bundleId: "com.google.Chrome",
            displayName: "Google Chrome",
            executableURL: nil,
            bundleURL: nil,
            processIdentifier: 200,
            activationPolicyRawValue: NSApplication.ActivationPolicy.regular.rawValue,
            isTerminated: false,
            isHidden: false
        )
        let config = ManagedAppConfiguration(
            id: UUID(),
            bundleId: "com.google.Chrome",
            displayName: "Google Chrome",
            appURLString: nil,
            isEnabled: true,
            shouldQuitBeforeSleep: true,
            shouldRestoreAfterWake: true,
            allowsForceTerminate: false,
            terminationTimeoutSeconds: 5,
            category: .browser,
            riskLevel: .medium
        )

        XCTAssertTrue(policy.isProtected(finder))
        XCTAssertFalse(policy.canTerminate(finder, managedConfiguration: nil))
        XCTAssertTrue(policy.canTerminate(chrome, managedConfiguration: config))
    }
}
