import AppKit
import Foundation

struct SystemRunningAppProvider: RunningAppProvider {
    func runningApplications() -> [RunningAppInfo] {
        NSWorkspace.shared.runningApplications
            .filter { !$0.isTerminated }
            .map {
                RunningAppInfo(
                    bundleId: $0.bundleIdentifier,
                    displayName: $0.localizedName ?? $0.bundleIdentifier ?? "pid \($0.processIdentifier)",
                    executableURL: $0.executableURL,
                    bundleURL: $0.bundleURL,
                    processIdentifier: $0.processIdentifier,
                    activationPolicyRawValue: $0.activationPolicy.rawValue,
                    isTerminated: $0.isTerminated,
                    isHidden: $0.isHidden
                )
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}
