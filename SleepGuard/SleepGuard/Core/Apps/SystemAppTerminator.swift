import AppKit
import Foundation

struct SystemAppTerminator: AppTerminating {
    var policy: ProtectedAppPolicy

    init(policy: ProtectedAppPolicy = ProtectedAppPolicy()) {
        self.policy = policy
    }

    func terminate(
        app: RunningAppInfo,
        configuration: ManagedAppConfiguration?,
        globalForceEnabled: Bool,
        mode: TerminationMode
    ) async -> TerminationResult {
        guard let configuration, policy.canTerminate(app, managedConfiguration: configuration) else {
            return policy.isProtected(app) ? .skippedProtected : .skippedNotAllowed
        }
        guard let runningApplication = NSRunningApplication(processIdentifier: app.processIdentifier) else {
            return .appNotFound
        }

        if runningApplication.terminate() {
            let gracefulResult = await waitUntilTerminated(runningApplication, timeout: configuration.terminationTimeoutSeconds)
            if gracefulResult == .success {
                return .success
            }
        }

        let mayForce = mode == .forceIfAllowed &&
            globalForceEnabled &&
            policy.canForceTerminate(app, managedConfiguration: configuration)
        guard mayForce else { return .timedOut }

        if runningApplication.forceTerminate() {
            let forceResult = await waitUntilTerminated(runningApplication, timeout: 3)
            return forceResult == .success ? .forceTerminated : .failed
        }
        return .failed
    }

    private func waitUntilTerminated(_ application: NSRunningApplication, timeout: TimeInterval) async -> TerminationResult {
        let started = Date()
        while !application.isTerminated {
            if Date().timeIntervalSince(started) >= timeout {
                return .timedOut
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return .success
    }
}
