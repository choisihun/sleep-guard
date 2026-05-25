import Foundation
import UserNotifications

protocol UserNotificationServicing {
    func requestAuthorization() async
    func showWakeReportNotification(report: SleepReport, session: SleepSession)
}

final class UserNotificationService: NSObject, UserNotificationServicing, UNUserNotificationCenterDelegate {
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    func showWakeReportNotification(report: SleepReport, session: SleepSession) {
        let content = UNMutableNotificationContent()
        content.title = "Sleep Guard 리포트가 준비됐습니다"
        let before = session.batteryBefore
        let after = session.batteryAfter ?? before
        content.body = "배터리 \(before)% → \(after)%, -\(max(0, before - after))%. DarkWake \(report.darkWakeCount)회 감지"
        content.sound = .default
        content.userInfo = ["reportId": report.id.uuidString]

        let request = UNNotificationRequest(identifier: report.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
