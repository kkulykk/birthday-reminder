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
}
