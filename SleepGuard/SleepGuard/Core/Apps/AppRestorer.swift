import Foundation

protocol AppRestoring {
    func restore(record: RunningAppRecord, shouldRestore: Bool) async -> RestoreResult
}
