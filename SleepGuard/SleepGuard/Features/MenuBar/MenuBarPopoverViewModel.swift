import Combine
import Foundation

@MainActor
final class MenuBarPopoverViewModel: ObservableObject {
    let controller: SleepGuardController
    private let openMainWindowAction: () -> Void

    init(controller: SleepGuardController, openMainWindow: @escaping () -> Void) {
        self.controller = controller
        self.openMainWindowAction = openMainWindow
    }

    func cleanAndSleep() async {
        await controller.cleanAndSleep()
    }

    func analyzeNow() async {
        await controller.analyzeNow()
    }

    func openMainWindow() {
        openMainWindowAction()
    }
}
