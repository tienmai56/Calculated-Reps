import Foundation
import UserNotifications

// MARK: - Reminder Scheduler

final class ReminderScheduler {
    static let shared = ReminderScheduler()
    private let notificationId = "matmind.reflection.reminder"

    func updateSchedule(enabled: Bool, hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])

        guard enabled else { return }

        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Time to reflect 📖"
            content.body = "How did training go? Take a minute to capture what worked and where you got stuck."
            content.sound = .default

            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: self.notificationId, content: content, trigger: trigger)
            center.add(request, withCompletionHandler: nil)
        }
    }

    func scheduleDefaultIfNeeded() {
        let enabled = UserDefaults.standard.object(forKey: "reminderEnabled") as? Bool ?? true
        let hour = UserDefaults.standard.object(forKey: "reminderHour") as? Int ?? 8
        let minute = UserDefaults.standard.object(forKey: "reminderMinute") as? Int ?? 0
        updateSchedule(enabled: enabled, hour: hour, minute: minute)
    }
}
