import UserNotifications
import Foundation

@MainActor
final class NotificationService {
    private let center = UNUserNotificationCenter.current()

    func requestPermission() async -> Bool {
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized { return true }
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Reschedules up to 64 notifications for the soonest upcoming uncongratulated birthdays.
    func rescheduleAll(people: [Person]) async {
        center.removeAllPendingNotificationRequests()

        let sorted = people
            .filter { $0.birthdayMonth != nil && !$0.isCongratulatedThisYear }
            .sorted { $0.nextBirthdayDate < $1.nextBirthdayDate }
            .prefix(64)

        for person in sorted {
            guard let month = person.birthdayMonth, let day = person.birthdayDay else { continue }

            let content = UNMutableNotificationContent()
            content.title = "🎂 \(person.fullName)'s Birthday"
            content.body = person.age.map { "Turning \($0) today!" } ?? "Don't forget to reach out!"
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            content.userInfo = ["personID": person.id.uuidString]

            let hour = UserDefaults.standard.object(forKey: "notificationHour") as? Int ?? 9
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: DateComponents(month: month, day: day, hour: hour, minute: 0),
                repeats: true
            )
            let request = UNNotificationRequest(
                identifier: "birthday-\(person.id.uuidString)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    func cancelNotification(for personID: UUID) {
        center.removePendingNotificationRequests(
            withIdentifiers: ["birthday-\(personID.uuidString)"]
        )
    }
}
