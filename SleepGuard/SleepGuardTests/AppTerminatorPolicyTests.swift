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
        XCTAssertFalse(policy.canForceTerminate(chrome, managedConfiguration: config))
    }

    func testForceTerminationRequiresPolicyAllowlistAndSafeCategory() {
        let policy = ProtectedAppPolicy(
            configuration: AppProtectionConfiguration(
                protectedBundleIds: [],
                protectedProcessNames: [],
                forceTerminationAllowedBundleIds: ["com.example.Utility"]
            )
        )
        let utility = RunningAppInfo(
            bundleId: "com.example.Utility",
            displayName: "Utility",
            executableURL: nil,
            bundleURL: nil,
            processIdentifier: 300,
            activationPolicyRawValue: NSApplication.ActivationPolicy.regular.rawValue,
            isTerminated: false,
            isHidden: false
        )
        var config = ManagedAppConfiguration(
            id: UUID(),
            bundleId: "com.example.Utility",
            displayName: "Utility",
            appURLString: nil,
            isEnabled: true,
            shouldQuitBeforeSleep: true,
            shouldRestoreAfterWake: true,
            allowsForceTerminate: true,
            terminationTimeoutSeconds: 5,
            category: .utility,
            riskLevel: .medium
        )

        XCTAssertTrue(policy.canForceTerminate(utility, managedConfiguration: config))

        config.category = .browser
        XCTAssertFalse(policy.canForceTerminate(utility, managedConfiguration: config))
    }

    func testAutoHighImpactTerminationDeniesHighDataLossApps() {
        let policy = ProtectedAppPolicy(configuration: .empty)
        let chrome = RunningAppInfo(
            bundleId: "com.google.Chrome",
            displayName: "Google Chrome",
            executableURL: nil,
            bundleURL: nil,
            processIdentifier: 400,
            activationPolicyRawValue: NSApplication.ActivationPolicy.regular.rawValue,
            isTerminated: false,
            isHidden: false
        )
        let xcode = RunningAppInfo(
            bundleId: "com.apple.dt.Xcode",
            displayName: "Xcode",
            executableURL: nil,
            bundleURL: nil,
            processIdentifier: 401,
            activationPolicyRawValue: NSApplication.ActivationPolicy.regular.rawValue,
            isTerminated: false,
            isHidden: false
        )
        let utility = RunningAppInfo(
            bundleId: "com.example.Renderer",
            displayName: "Renderer",
            executableURL: nil,
            bundleURL: nil,
            processIdentifier: 402,
            activationPolicyRawValue: NSApplication.ActivationPolicy.regular.rawValue,
            isTerminated: false,
            isHidden: false
        )

        XCTAssertFalse(policy.canAutoTerminateHighImpactApp(chrome))
        XCTAssertFalse(policy.canAutoTerminateHighImpactApp(xcode))
        XCTAssertTrue(policy.canAutoTerminateHighImpactApp(utility))
    }
}
