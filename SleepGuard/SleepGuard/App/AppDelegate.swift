import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var container: AppDependencyContainer?
    private var statusBarController: StatusBarController?
    private var mainWindowController: MainWindowController?
    private var powerEventMonitor: PowerEventMonitoring?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            NSApp.setActivationPolicy(.accessory)
            return
        }

        do {
            let container = try AppDependencyContainer()
            self.container = container

            let mainWindowController = MainWindowController(container: container)
            self.mainWindowController = mainWindowController

            statusBarController = StatusBarController(
                controller: container.controller,
                openMainWindow: { [weak mainWindowController] in
                    mainWindowController?.show()
                }
            )

            let monitor = SystemPowerEventMonitor()
            monitor.onWillSleep = { [weak controller = container.controller] in
                Task { await controller?.handleWillSleep() }
            }
            monitor.onDidWake = { [weak controller = container.controller] in
                Task { await controller?.handleDidWake() }
            }
            monitor.onScreensDidSleep = { [weak controller = container.controller] in
                Task { await controller?.analyzeNow() }
            }
            monitor.start()
            powerEventMonitor = monitor

            Task { @MainActor in
                do {
                    let settings = try await container.settingsStore.fetchOrCreate()
                    NSApp.setActivationPolicy(settings.showDockIcon ? .regular : .accessory)
                    if ProcessInfo.processInfo.environment["SLEEP_GUARD_UI_TESTING"] == "1" {
                        await container.controller.refreshCurrentState()
                    } else {
                        await container.controller.bootstrap()
                    }
                } catch {
                    NSAlert(error: error).runModal()
                    NSApp.terminate(nil)
                }
            }

        } catch {
            NSAlert(error: error).runModal()
            NSApp.terminate(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
