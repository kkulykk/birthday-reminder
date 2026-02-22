import SwiftData
import Foundation

@Model
final class Person {
    var id: UUID = UUID()
    var givenName: String = ""
    var familyName: String = ""
    var birthdayMonth: Int?
    var birthdayDay: Int?
    var birthdayYear: Int?
    var contactIdentifier: String?
    var phoneNumber: String?
    var email: String?
    var photoData: Data?
    var notes: String?
    var congratulatedYear: Int?
    var missedYear: Int?
    var isExcluded: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \WishlistItem.person)
    var wishlistItems: [WishlistItem] = []

    init() {}

    // MARK: - Computed helpers

    var fullName: String {
        "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces)
    }

    var initials: String {
        let g = givenName.first.map(String.init) ?? ""
        let f = familyName.first.map(String.init) ?? ""
        return (g + f).uppercased()
    }

    var isCongratulatedThisYear: Bool {
        congratulatedYear == Calendar.current.component(.year, from: Date())
    }

    var age: Int? {
        guard let year = birthdayYear,
              let month = birthdayMonth,
              let day = birthdayDay else { return nil }
        let now = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        var calculatedAge = (now.year ?? 0) - year
        if let m = now.month, let d = now.day {
            if m < month || (m == month && d < day) { calculatedAge -= 1 }
        }
        return max(0, calculatedAge)
    }

    /// Next upcoming birthday date (this calendar year or next)
    var nextBirthdayDate: Date {
        guard let month = birthdayMonth, let day = birthdayDay else { return .distantFuture }
        let cal = Calendar.current
        let today = Date()
        var comps = DateComponents()
        comps.month = month
        comps.day = day
        comps.year = cal.component(.year, from: today)
        if let candidate = cal.date(from: comps), candidate >= cal.startOfDay(for: today) {
            return candidate
        }
        comps.year = (comps.year ?? 0) + 1
        return cal.date(from: comps) ?? .distantFuture
    }

    var isBirthdayToday: Bool {
        let cal = Calendar.current
        let today = cal.dateComponents([.month, .day], from: Date())
        return today.month == birthdayMonth && today.day == birthdayDay
    }

    /// Days since birthday passed (negative = still upcoming, 0 = today, 1 = yesterday)
    var daysSinceBirthday: Int? {
        guard let month = birthdayMonth, let day = birthdayDay else { return nil }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var comps = DateComponents()
        comps.month = month
        comps.day = day
        comps.year = cal.component(.year, from: today)
        guard let thisYearBirthday = cal.date(from: comps) else { return nil }
        return cal.dateComponents([.day], from: thisYearBirthday, to: today).day
    }

    /// True if the birthday was yesterday and still uncongratulated
    var isMissedYesterday: Bool {
        let thisYear = Calendar.current.component(.year, from: Date())
        guard congratulatedYear != thisYear, missedYear != thisYear else { return false }
        return daysSinceBirthday == 1
    }

    /// Should be auto-marked as missed (2+ days past, not congratulated or missed yet)
    var shouldAutoMarkMissed: Bool {
        let thisYear = Calendar.current.component(.year, from: Date())
        guard congratulatedYear != thisYear, missedYear != thisYear else { return false }
        return (daysSinceBirthday ?? 0) >= 2
    }

    /// Formatted birthday string for display
    var birthdayDisplayString: String {
        guard let month = birthdayMonth, let day = birthdayDay else { return "Unknown" }
        var comps = DateComponents()
        comps.month = month
        comps.day = day
        comps.year = birthdayYear ?? 2000
        let cal = Calendar.current
        guard let date = cal.date(from: comps) else { return "\(month)/\(day)" }
        let formatter = DateFormatter()
        formatter.dateFormat = birthdayYear != nil ? "MMMM d, yyyy" : "MMMM d"
        return formatter.string(from: date)
    }

    /// Most recent past birthday date (today or earlier)
    var lastBirthdayDate: Date {
        guard let month = birthdayMonth, let day = birthdayDay else { return .distantPast }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var comps = DateComponents()
        comps.month = month
        comps.day = day
        comps.year = cal.component(.year, from: today)
        if let thisYear = cal.date(from: comps), thisYear <= today {
            return thisYear
        }
        comps.year = (comps.year ?? 0) - 1
        return cal.date(from: comps) ?? .distantPast
    }

    /// How many days have passed since the last birthday (0 = today)
    var daysSinceLastBirthday: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let last = cal.startOfDay(for: lastBirthdayDate)
        return cal.dateComponents([.day], from: last, to: today).day ?? 0
    }

    /// True when `congratulatedYear` matches the year of the last birthday (rolling-year aware)
    var isCongratulatedOnLastBirthday: Bool {
        guard let cy = congratulatedYear else { return false }
        return cy == Calendar.current.component(.year, from: lastBirthdayDate)
    }

    /// Age the person turns on their next birthday
    var turningAge: Int? {
        guard let year = birthdayYear else { return nil }
        let cal = Calendar.current
        let nextYear = cal.component(.year, from: nextBirthdayDate)
        return nextYear - year
    }

    /// Days until next birthday (0 = today)
    var daysUntilBirthday: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let next = cal.startOfDay(for: nextBirthdayDate)
        return cal.dateComponents([.day], from: today, to: next).day ?? 0
    }
}
