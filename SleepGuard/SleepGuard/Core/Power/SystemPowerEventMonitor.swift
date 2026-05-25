import AppKit
import Foundation

final class SystemPowerEventMonitor: PowerEventMonitoring {
    var onWillSleep: (() -> Void)?
    var onDidWake: (() -> Void)?
    var onScreensDidSleep: (() -> Void)?
    var onScreensDidWake: (() -> Void)?

    private var observers: [NSObjectProtocol] = []

    func start() {
        stop()
        let center = NSWorkspace.shared.notificationCenter
        observers = [
            center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
                self?.onWillSleep?()
            },
            center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.onDidWake?()
            },
            center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
                self?.onScreensDidSleep?()
            },
            center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.onScreensDidWake?()
            }
        ]
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach { center.removeObserver($0) }
        observers.removeAll()
    }

    deinit {
        stop()
    }
}
