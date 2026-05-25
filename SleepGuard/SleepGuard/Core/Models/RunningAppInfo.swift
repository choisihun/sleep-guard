import AppKit
import Foundation

struct RunningAppInfo: Identifiable, Codable, Hashable {
    var id: Int32 { processIdentifier }
    var bundleId: String?
    var displayName: String
    var executableURL: URL?
    var bundleURL: URL?
    var processIdentifier: pid_t
    var activationPolicyRawValue: Int
    var isTerminated: Bool
    var isHidden: Bool

    var activationPolicy: NSApplication.ActivationPolicy {
        NSApplication.ActivationPolicy(rawValue: activationPolicyRawValue) ?? .prohibited
    }
}

struct RunningAppRecord: Codable, Hashable, Identifiable {
    var id: String { "\(bundleId ?? displayName)-\(pid)" }
    var bundleId: String?
    var displayName: String
    var appURLString: String?
    var pid: Int32
    var wasRunning: Bool
    var wasTerminatedBySleepGuard: Bool
    var wasRestoredBySleepGuard: Bool
    var terminationResultRawValue: String?

    init(
        bundleId: String?,
        displayName: String,
        appURLString: String?,
        pid: Int32,
        wasRunning: Bool = true,
        wasTerminatedBySleepGuard: Bool = false,
        wasRestoredBySleepGuard: Bool = false,
        terminationResultRawValue: String? = nil
    ) {
        self.bundleId = bundleId
        self.displayName = displayName
        self.appURLString = appURLString
        self.pid = pid
        self.wasRunning = wasRunning
        self.wasTerminatedBySleepGuard = wasTerminatedBySleepGuard
        self.wasRestoredBySleepGuard = wasRestoredBySleepGuard
        self.terminationResultRawValue = terminationResultRawValue
    }

    init(app: RunningAppInfo) {
        self.init(
            bundleId: app.bundleId,
            displayName: app.displayName,
            appURLString: app.bundleURL?.absoluteString ?? app.executableURL?.absoluteString,
            pid: app.processIdentifier
        )
    }
}
