import Combine
import Foundation

@MainActor
final class ReportsViewModel: ObservableObject {
    @Published private(set) var isSyncing = false

    let controller: SleepGuardController
    private let autoSyncIntervalNanoseconds: UInt64

    init(controller: SleepGuardController, autoSyncIntervalNanoseconds: UInt64 = 10_000_000_000) {
        self.controller = controller
        self.autoSyncIntervalNanoseconds = autoSyncIntervalNanoseconds
    }

    func autoSyncHistory() async {
        await refresh()

        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: autoSyncIntervalNanoseconds)
            } catch {
                return
            }
            await refresh()
        }
    }

    func refresh() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        await controller.reloadHistory()
    }

    func reanalyze(reportId: UUID) async {
        await controller.reanalyzeReport(id: reportId)
    }
}
