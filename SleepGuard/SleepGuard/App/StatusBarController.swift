import AppKit
import SwiftUI

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popoverController: PopoverController
    private let openMainWindowAction: () -> Void
    private let analyzeNowAction: () -> Void

    private lazy var statusMenu: NSMenu = {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let openItem = NSMenuItem(title: "Sleep Guard 열기", action: #selector(openMainWindowFromMenu), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let analyzeItem = NSMenuItem(title: "현재 상태 분석", action: #selector(analyzeNowFromMenu), keyEquivalent: "")
        analyzeItem.target = self
        menu.addItem(analyzeItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "종료", action: #selector(quitFromMenu), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }()

    init(controller: SleepGuardController, openMainWindow: @escaping () -> Void) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popoverController = PopoverController(controller: controller, openMainWindow: openMainWindow)
        openMainWindowAction = openMainWindow
        analyzeNowAction = {
            Task { await controller.analyzeNow() }
        }
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "moon.zzz.fill", accessibilityDescription: "Sleep Guard")
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        if shouldShowContextMenu(for: NSApp.currentEvent) {
            showContextMenu(from: sender)
        } else {
            togglePopover(from: sender)
        }
    }

    private func shouldShowContextMenu(for event: NSEvent?) -> Bool {
        event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
    }

    private func togglePopover(from button: NSStatusBarButton) {
        popoverController.toggle(relativeTo: button.bounds, of: button)
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        popoverController.close()
        statusMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }

    @objc private func openMainWindowFromMenu() {
        popoverController.close()
        openMainWindowAction()
    }

    @objc private func analyzeNowFromMenu() {
        popoverController.close()
        analyzeNowAction()
    }

    @objc private func quitFromMenu() {
        popoverController.close()
        NSApp.terminate(nil)
    }
}
