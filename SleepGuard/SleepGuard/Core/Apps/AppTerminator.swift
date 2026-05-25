import Foundation

protocol AppTerminating {
    func terminate(
        app: RunningAppInfo,
        configuration: ManagedAppConfiguration?,
        globalForceEnabled: Bool,
        mode: TerminationMode
    ) async -> TerminationResult
}
