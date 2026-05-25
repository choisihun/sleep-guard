import AppKit
import SwiftUI

final class MainWindowController: NSWindowController {
    private let container: AppDependencyContainer

    init(container: AppDependencyContainer) {
        self.container = container
        let rootView = MainWindowView(
            viewModel: MainWindowViewModel(
                controller: container.controller,
                managedAppStore: container.managedAppStore,
                settingsStore: container.settingsStore,
                loginItemManager: container.loginItemManager,
                openMainWindow: {}
            )
        )
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Sleep Guard"
        window.setContentSize(NSSize(width: 1040, height: 720))
        window.minSize = NSSize(width: 900, height: 640)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
