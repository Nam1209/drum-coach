import DrumAI
import Foundation
import UserNotifications

/// Local notifications: a daily practice reminder and the Sunday "meet your teacher" reminder; reinstall-expiry warning.
@MainActor
enum ReminderScheduler {
    static var dailyHour: Int {
        get { UserDefaults.standard.object(forKey: "reminderHour") as? Int ?? 19 }
        set { UserDefaults.standard.set(newValue, forKey: "reminderHour") }
    }

    /// Already allowed (never shows the system prompt).
    static func isAuthorized() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }

    /// Shows the system prompt the first time; asked when the learner starts practising, not at launch.
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Last plan text used for reminders, so a reschedule from the practice screen keeps the teacher's wording.
    private static var lastPlan: DayPlan?

    static func schedule(today plan: DayPlan?, practicedToday: Bool) {
        let center = UNUserNotificationCenter.current()
        if let plan { lastPlan = plan }
        let ids = (0...14).map { "daily-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids + ["daily", "weekly"])

        let c = ReminderContent.daily(plan ?? lastPlan)
        let cal = Calendar.current
        // One-shot reminders for the next two weeks: they keep coming even if the app is not opened.
        for offset in ReminderContent.dayOffsets(practicedToday: practicedToday, count: 14) {
            guard let day = cal.date(byAdding: .day, value: offset, to: Date()),
                  let fire = cal.date(bySettingHour: dailyHour, minute: 0, second: 0, of: day), fire > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.title = c.title
            content.body = c.body
            let trigger = UNCalendarNotificationTrigger(dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire), repeats: false)
            center.add(UNNotificationRequest(identifier: "daily-\(offset)", content: content, trigger: trigger))
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
