import AppKit
import SwiftUI

final class PopoverController: NSObject, NSPopoverDelegate {
    private let popover = NSPopover()
    private var eventMonitors: [Any] = []

    init(controller: SleepGuardController, openMainWindow: @escaping () -> Void) {
        super.init()

        let viewModel = MenuBarPopoverViewModel(controller: controller, openMainWindow: openMainWindow)
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 380, height: 520)
        popover.contentViewController = NSHostingController(rootView: MenuBarPopoverView(viewModel: viewModel))
    }

    func toggle(relativeTo rect: NSRect, of view: NSView) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: rect, of: view, preferredEdge: .minY)
            startOutsideClickMonitoring(anchorView: view)
        }
    }

    func close() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            stopOutsideClickMonitoring()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        stopOutsideClickMonitoring()
    }

    private func startOutsideClickMonitoring(anchorView: NSView) {
        stopOutsideClickMonitoring()

        let eventMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if let localMonitor = NSEvent.addLocalMonitorForEvents(matching: eventMask, handler: { [weak self, weak anchorView] event in
            guard let self else { return event }
            if self.shouldKeepOpen(for: event, anchorView: anchorView) {
                return event
            }
            self.close()
            return event
        }) {
            eventMonitors.append(localMonitor)
        }

        if let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask, handler: { [weak self] _ in
            self?.close()
        }) {
            eventMonitors.append(globalMonitor)
        }
    }

    private func shouldKeepOpen(for event: NSEvent, anchorView: NSView?) -> Bool {
        if event.window == popover.contentViewController?.view.window {
            return true
        }

        guard let anchorView, event.window == anchorView.window else {
            return false
        }

        let location = anchorView.convert(event.locationInWindow, from: nil)
        return anchorView.bounds.contains(location)
    }

    private func stopOutsideClickMonitoring() {
        eventMonitors.forEach(NSEvent.removeMonitor)
        eventMonitors.removeAll()
    }
}
