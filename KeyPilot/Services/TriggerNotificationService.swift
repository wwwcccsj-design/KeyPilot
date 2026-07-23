import Foundation
import UserNotifications

final class TriggerNotificationService {
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in
            // The current setting remains user-controlled even when authorization is declined.
        }
    }

    func show(for action: ShortcutAction) {
        let content = UNMutableNotificationContent()
        content.title = "KeyPilot"
        switch action {
        case let .launchApplication(target):
            content.body = "已触发 \(target.displayName)"
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
