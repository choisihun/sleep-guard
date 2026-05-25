import AppKit
import SwiftUI

final class PopoverController {
    private let popover = NSPopover()

    init(controller: SleepGuardController, openMainWindow: @escaping () -> Void) {
        let viewModel = MenuBarPopoverViewModel(controller: controller, openMainWindow: openMainWindow)
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 380, height: 520)
        popover.contentViewController = NSHostingController(rootView: MenuBarPopoverView(viewModel: viewModel))
    }

    func toggle(relativeTo rect: NSRect, of view: NSView) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: rect, of: view, preferredEdge: .minY)
        }
    }
}
