import Foundation

protocol PowerEventMonitoring: AnyObject {
    var onWillSleep: (() -> Void)? { get set }
    var onDidWake: (() -> Void)? { get set }
    var onScreensDidSleep: (() -> Void)? { get set }
    var onScreensDidWake: (() -> Void)? { get set }

    func start()
    func stop()
}
