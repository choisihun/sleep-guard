import Combine
import Foundation

@MainActor
final class ReportsViewModel: ObservableObject {
    let controller: SleepGuardController

    init(controller: SleepGuardController) {
        self.controller = controller
    }

    func refresh() async {
        await controller.reloadHistory()
    }

    func reanalyze(reportId: UUID) async {
        await controller.reanalyzeReport(id: reportId)
    }
}
