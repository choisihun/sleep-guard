import Combine
import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    let controller: SleepGuardController

    init(controller: SleepGuardController) {
        self.controller = controller
    }

    func cleanAndSleep() async {
        await controller.cleanAndSleep()
    }

    func analyzeNow() async {
        await controller.analyzeNow()
    }
}
