import AppKit
import Testing
@testable import SleepGuard

struct SuspiciousAppDetectorTests {
    @Test func doesNotFlagAppsFromHardcodedCatalog() {
        let chrome = RunningAppInfo(
            bundleId: "com.google.Chrome",
            displayName: "Google Chrome",
            executableURL: nil,
            bundleURL: URL(fileURLWithPath: "/Applications/Google Chrome.app"),
            processIdentifier: 101,
            activationPolicyRawValue: NSApplication.ActivationPolicy.regular.rawValue,
            isTerminated: false,
            isHidden: false
        )
        let finder = RunningAppInfo(
            bundleId: "com.apple.finder",
            displayName: "Finder",
            executableURL: nil,
            bundleURL: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"),
            processIdentifier: 102,
            activationPolicyRawValue: NSApplication.ActivationPolicy.regular.rawValue,
            isTerminated: false,
            isHidden: false
        )

        let suspicious = SuspiciousAppDetector().suspiciousApps(runningApps: [chrome, finder], managedApps: [])

        #expect(suspicious.isEmpty)
    }

    @Test func detectsEnabledManagedApps() {
        let app = RunningAppInfo(
            bundleId: "com.example.HeavyApp",
            displayName: "HeavyApp",
            executableURL: nil,
            bundleURL: URL(fileURLWithPath: "/Applications/HeavyApp.app"),
            processIdentifier: 201,
            activationPolicyRawValue: NSApplication.ActivationPolicy.regular.rawValue,
            isTerminated: false,
            isHidden: false
        )
        let managed = ManagedApp(
            bundleId: "com.example.HeavyApp",
            displayName: "HeavyApp",
            isEnabled: true
        )

        let suspicious = SuspiciousAppDetector().suspiciousApps(runningApps: [app], managedApps: [managed])

        #expect(suspicious.map(\.displayName) == ["HeavyApp"])
    }

    @Test func detectsHighEnergyAppsBeforeTheyAreManaged() {
        let codex = RunningAppInfo(
            bundleId: "com.openai.codex",
            displayName: "Codex",
            executableURL: nil,
            bundleURL: URL(fileURLWithPath: "/Applications/Codex.app"),
            processIdentifier: 301,
            activationPolicyRawValue: NSApplication.ActivationPolicy.regular.rawValue,
            isTerminated: false,
            isHidden: false
        )
        let impact = AppEnergyImpact(
            app: codex,
            cpuPercent: 35,
            memoryMB: 900,
            score: 80,
            level: .high,
            reasons: ["CPU 높음"]
        )

        let suspicious = SuspiciousAppDetector().suspiciousApps(
            runningApps: [codex],
            managedApps: [],
            energyImpacts: [impact]
        )

        #expect(suspicious.map(\.displayName) == ["Codex"])
    }

    @Test func ignoresProtectedHighEnergyApps() {
        let finder = RunningAppInfo(
            bundleId: "com.apple.finder",
            displayName: "Finder",
            executableURL: nil,
            bundleURL: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"),
            processIdentifier: 302,
            activationPolicyRawValue: NSApplication.ActivationPolicy.regular.rawValue,
            isTerminated: false,
            isHidden: false
        )
        let impact = AppEnergyImpact(
            app: finder,
            cpuPercent: 80,
            memoryMB: 500,
            score: 90,
            level: .high,
            reasons: ["CPU 높음"]
        )

        let suspicious = SuspiciousAppDetector(
            policy: ProtectedAppPolicy(
                configuration: AppProtectionConfiguration(
                    protectedBundleIds: ["com.apple.finder"],
                    protectedProcessNames: ["Finder"]
                )
            )
        )
        .suspiciousApps(runningApps: [finder], managedApps: [], energyImpacts: [impact])

        #expect(suspicious.isEmpty)
    }

    @Test func ignoresDisabledManagedApps() {
        let app = RunningAppInfo(
            bundleId: "com.example.HeavyApp",
            displayName: "HeavyApp",
            executableURL: nil,
            bundleURL: URL(fileURLWithPath: "/Applications/HeavyApp.app"),
            processIdentifier: 201,
            activationPolicyRawValue: NSApplication.ActivationPolicy.regular.rawValue,
            isTerminated: false,
            isHidden: false
        )
        let managed = ManagedApp(
            bundleId: "com.example.HeavyApp",
            displayName: "HeavyApp",
            isEnabled: false
        )

        let suspicious = SuspiciousAppDetector().suspiciousApps(runningApps: [app], managedApps: [managed])

        #expect(suspicious.isEmpty)
    }
}
