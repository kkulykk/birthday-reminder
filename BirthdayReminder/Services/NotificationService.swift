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
            content.body = person.turningAge.map { "Turning \($0) today!" } ?? "Don't forget to reach out!"
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0
            content.userInfo = ["personID": person.id.uuidString]

            // Fire at 00:00 on the birthday so the notification sits on the lock
            // screen all day. If today is already their birthday (app opened after
            // midnight), fire immediately instead — the calendar trigger would
            // otherwise skip to next year since midnight already passed.
            let trigger: UNNotificationTrigger
            if person.isBirthdayToday {
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
            } else {
                trigger = UNCalendarNotificationTrigger(
                    dateMatching: DateComponents(month: month, day: day, hour: 0, minute: 0),
                    repeats: true
                )
            }

            let request = UNNotificationRequest(
                identifier: "birthday-\(person.id.uuidString)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    func cancelNotification(for personID: UUID) {
        let id = "birthday-\(personID.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }
}
