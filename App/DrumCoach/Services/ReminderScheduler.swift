import DrumAI
import Foundation
import UserNotifications

/// Local notifications: a daily practice reminder and the Sunday "meet your teacher" reminder; reinstall-expiry warning.
enum ReminderScheduler {
    static var dailyHour: Int {
        get { UserDefaults.standard.object(forKey: "reminderHour") as? Int ?? 19 }
        set { UserDefaults.standard.set(newValue, forKey: "reminderHour") }
    }

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func schedule(today plan: DayPlan?, practicedToday: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily", "weekly"])

        let c = ReminderContent.daily(plan)
        let daily = UNMutableNotificationContent()
        daily.title = c.title
        daily.body = c.body
        var when = DateComponents()
        when.hour = dailyHour
        // When today's practice is done, start reminding from tomorrow.
        if practicedToday, let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
            let d = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
            when.year = d.year; when.month = d.month; when.day = d.day
            center.add(UNNotificationRequest(identifier: "daily", content: daily, trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false)))
        } else {
            center.add(UNNotificationRequest(identifier: "daily", content: daily, trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true)))
        }

        let weekly = UNMutableNotificationContent()
        weekly.title = ReminderContent.weekly.title
        weekly.body = ReminderContent.weekly.body
        var sunday = DateComponents()
        sunday.weekday = 1
        sunday.hour = 9
        center.add(UNNotificationRequest(identifier: "weekly", content: weekly, trigger: UNCalendarNotificationTrigger(dateMatching: sunday, repeats: true)))
    }

    /// When this build was installed (the executable's creation date).
    static var installDate: Date? {
        Bundle.main.executableURL.flatMap { try? FileManager.default.attributesOfItem(atPath: $0.path)[.creationDate] as? Date }
    }

    static var expiryDate: Date? { installDate?.addingTimeInterval(7 * 86_400) }

    /// Free Apple ID builds expire 7 days after install: remind a day before.
    static func scheduleReinstallReminder(installDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Cài lại DrumCoach"
        content.body = "Bản cài hết hạn ngày mai. Cắm iPad vào Mac và bấm Run trong Xcode — lịch sử vẫn giữ nguyên."
        let fire = installDate.addingTimeInterval(6 * 86_400)
        guard fire > Date() else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fire.timeIntervalSinceNow, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "reinstall", content: content, trigger: trigger))
    }
}
