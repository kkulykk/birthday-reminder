import Foundation

struct WidgetBirthday: Codable, Identifiable {
    let id: UUID
    let name: String
    let daysUntil: Int
    let isBirthdayToday: Bool
    let monthDay: String // e.g. "Feb 23"
}

enum WidgetDataManager {
    static let suiteName = "group.kkulykk.BirthdayReminder"
    static let key = "widgetUpcomingBirthdays"

    static func save(_ birthdays: [WidgetBirthday]) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = try? JSONEncoder().encode(birthdays) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> [WidgetBirthday] {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: key),
              let birthdays = try? JSONDecoder().decode([WidgetBirthday].self, from: data)
        else { return [] }
        return birthdays
    }

    // MARK: - Widget display helpers (shared + testable)

    /// Returns the section header label for the rectangular widget.
    /// Shows "Birthday" for today's birthdays, "Upcoming" for future ones,
    /// and "None this week" when there are none.
    static func widgetSectionLabel(nearest: [WidgetBirthday]) -> String {
        if nearest.isEmpty { return "None this week" }
        if nearest.first?.isBirthdayToday == true { return "Birthday" }
        return "Upcoming"
    }

    /// Projects stored birthday data forward by `dayOffset` days.
    /// Used to pre-build multiple timeline entries so the widget stays
    /// accurate without needing the app to be in the foreground.
    ///
    /// - Returns birthdays with adjusted `daysUntil`, filtered to the
    ///   7-day window relevant for the given offset day.
    static func adjustedBirthdays(from stored: [WidgetBirthday], dayOffset: Int) -> [WidgetBirthday] {
        stored.compactMap { birthday -> WidgetBirthday? in
            let adjustedDays = birthday.daysUntil - dayOffset
            guard adjustedDays >= 0 && adjustedDays <= 7 else { return nil }
            return WidgetBirthday(
                id: birthday.id,
                name: birthday.name,
                daysUntil: adjustedDays,
                isBirthdayToday: adjustedDays == 0,
                monthDay: birthday.monthDay
            )
        }
    }
}
