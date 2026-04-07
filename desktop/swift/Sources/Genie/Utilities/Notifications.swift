import UserNotifications
import os

enum GenieNotifications {
    private static let logger = Logger(subsystem: "com.gtrush.genie", category: "notifications")

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                logger.info("Notification permission granted")
            } else if let error {
                logger.error("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    static func send(title: String, body: String, identifier: String = UUID().uuidString) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                logger.error("Failed to send notification: \(error.localizedDescription)")
            }
        }
    }
}
