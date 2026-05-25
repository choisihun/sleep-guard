import AppKit
import SwiftUI

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popoverController: PopoverController

    init(controller: SleepGuardController, openMainWindow: @escaping () -> Void) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popoverController = PopoverController(controller: controller, openMainWindow: openMainWindow)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "moon.zzz.fill", accessibilityDescription: "Sleep Guard")
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(togglePopover)
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        popoverController.toggle(relativeTo: button.bounds, of: button)
    }
}
