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
            SleepGuardShortcutCoordinator.shared.register(container: container)

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
                Task { await controller?.handleScreensDidSleep() }
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
                        await offerLaunchAtLoginIfNeeded(
                            settings: settings,
                            settingsStore: container.settingsStore,
                            loginItemManager: container.loginItemManager
                        )
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

    @MainActor
    private func offerLaunchAtLoginIfNeeded(
        settings: AppSettings,
        settingsStore: SettingsStoring,
        loginItemManager: LoginItemManaging
    ) async {
        if loginItemManager.isEnabled {
            var needsSave = false
            if !settings.launchAtLogin {
                settings.launchAtLogin = true
                needsSave = true
            }
            if !settings.hasShownLaunchAtLoginPrompt {
                settings.hasShownLaunchAtLoginPrompt = true
                needsSave = true
            }
            if needsSave {
                try? await settingsStore.save(settings)
            }
            return
        }

        guard !settings.launchAtLogin, !settings.hasShownLaunchAtLoginPrompt else { return }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Mac을 켤 때 Sleep Guard 자동 실행"
        alert.informativeText = "맥북을 덮을 때 자동 정리하려면 Sleep Guard가 실행 중이어야 합니다. 로그인 시 자동 실행을 켜두면 덮개 닫힘과 시스템 잠자기 이벤트를 놓치지 않습니다."
        alert.addButton(withTitle: "로그인 시 실행 켜기")
        alert.addButton(withTitle: "나중에")

        settings.hasShownLaunchAtLoginPrompt = true
        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try loginItemManager.enable()
                settings.launchAtLogin = true
            } catch {
                NSAlert(error: error).runModal()
            }
        }
        try? await settingsStore.save(settings)
    }
}
