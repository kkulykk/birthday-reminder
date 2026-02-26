import XCTest
import SwiftData
@testable import BirthdayReminder

final class CalendarViewTests: XCTestCase {

    // MARK: - Helpers

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([Person.self, WishlistItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
        try super.tearDownWithError()
    }

    private func makePerson(month: Int? = nil, day: Int? = nil, isExcluded: Bool = false) -> Person {
        let p = Person()
        p.birthdayMonth = month
        p.birthdayDay = day
        p.isExcluded = isExcluded
        context.insert(p)
        return p
    }

    private func firstOfMonth(year: Int, month: Int, calendar: Calendar = .current) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        return calendar.date(from: comps)!
    }

    // MARK: - gridDates

    func testGridDates_alwaysReturns42() {
        // Test several different months to confirm count is always 42
        let months = [
            firstOfMonth(year: 2026, month: 1),
            firstOfMonth(year: 2026, month: 2),
            firstOfMonth(year: 2024, month: 2),
            firstOfMonth(year: 2025, month: 7),
            firstOfMonth(year: 2025, month: 12),
        ]
        for month in months {
            XCTAssertEqual(CalendarViewLogic.gridDates(for: month).count, 42, "Expected 42 for \(month)")
        }
    }

    func testGridDates_leadingNilsMatchWeekdayOffset() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1 // Sunday = 1

        // Feb 1, 2026 falls on a Sunday (weekday 1), so offset should be 0
        let feb2026 = firstOfMonth(year: 2026, month: 2, calendar: calendar)
        let slots = CalendarViewLogic.gridDates(for: feb2026, calendar: calendar)
        let leadingNils = slots.prefix(while: { $0 == nil }).count
        let firstWeekday = calendar.component(.weekday, from: feb2026)
        let expectedOffset = (firstWeekday - calendar.firstWeekday + 7) % 7
        XCTAssertEqual(leadingNils, expectedOffset)

        // March 1, 2026 falls on a Sunday too — offset 0
        let mar2026 = firstOfMonth(year: 2026, month: 3, calendar: calendar)
        let marSlots = CalendarViewLogic.gridDates(for: mar2026, calendar: calendar)
        let marLeadingNils = marSlots.prefix(while: { $0 == nil }).count
        let marFirstWeekday = calendar.component(.weekday, from: mar2026)
        let marExpectedOffset = (marFirstWeekday - calendar.firstWeekday + 7) % 7
        XCTAssertEqual(marLeadingNils, marExpectedOffset)
    }

    func testGridDates_allDaysOfMonthPresent() {
        let calendar = Calendar.current
        let month = firstOfMonth(year: 2025, month: 6) // June: 30 days
        let slots = CalendarViewLogic.gridDates(for: month, calendar: calendar)
        let nonNilDays = slots.compactMap { $0 }.map { calendar.component(.day, from: $0) }
        XCTAssertEqual(nonNilDays.count, 30)
        for day in 1...30 {
            XCTAssertTrue(nonNilDays.contains(day), "Day \(day) missing from June 2025")
        }
    }

    func testGridDates_february2026_28days() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1

        let feb2026 = firstOfMonth(year: 2026, month: 2, calendar: calendar)
        let slots = CalendarViewLogic.gridDates(for: feb2026, calendar: calendar)

        // Feb 2026 has 28 days
        let nonNilSlots = slots.compactMap { $0 }
        XCTAssertEqual(nonNilSlots.count, 28)

        // Feb 1, 2026 is a Sunday (weekday 1 in a Sunday-first calendar) → offset 0
        let firstWeekday = calendar.component(.weekday, from: feb2026)
        let offset = (firstWeekday - calendar.firstWeekday + 7) % 7
        XCTAssertEqual(offset, 0)
        // Since offset = 0, the first slot should be non-nil (day 1)
        XCTAssertNotNil(slots[0])
    }

    func testGridDates_february2024_leapYear_29days() {
        let calendar = Calendar.current
        let feb2024 = firstOfMonth(year: 2024, month: 2, calendar: calendar)
        let slots = CalendarViewLogic.gridDates(for: feb2024, calendar: calendar)
        let nonNilSlots = slots.compactMap { $0 }
        XCTAssertEqual(nonNilSlots.count, 29)
    }

    func testGridDates_december_31days() {
        let calendar = Calendar.current
        let dec2025 = firstOfMonth(year: 2025, month: 12, calendar: calendar)
        let slots = CalendarViewLogic.gridDates(for: dec2025, calendar: calendar)
        let nonNilSlots = slots.compactMap { $0 }
        XCTAssertEqual(nonNilSlots.count, 31)
    }

    // MARK: - nextMonth

    func testNextMonth_advancesOneMonth() {
        let calendar = Calendar.current
        let june = firstOfMonth(year: 2025, month: 6)
        let next = CalendarViewLogic.nextMonth(june, calendar: calendar)
        let comps = calendar.dateComponents([.year, .month], from: next)
        XCTAssertEqual(comps.year, 2025)
        XCTAssertEqual(comps.month, 7)
    }

    func testNextMonth_decemberWrapsToJanuary() {
        let calendar = Calendar.current
        let dec2025 = firstOfMonth(year: 2025, month: 12)
        let next = CalendarViewLogic.nextMonth(dec2025, calendar: calendar)
        let comps = calendar.dateComponents([.year, .month], from: next)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 1)
    }

    // MARK: - previousMonth

    func testPreviousMonth_goesBackOneMonth() {
        let calendar = Calendar.current
        let march = firstOfMonth(year: 2026, month: 3)
        let prev = CalendarViewLogic.previousMonth(march, calendar: calendar)
        let comps = calendar.dateComponents([.year, .month], from: prev)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 2)
    }

    func testPreviousMonth_januaryWrapsToDecember() {
        let calendar = Calendar.current
        let jan2026 = firstOfMonth(year: 2026, month: 1)
        let prev = CalendarViewLogic.previousMonth(jan2026, calendar: calendar)
        let comps = calendar.dateComponents([.year, .month], from: prev)
        XCTAssertEqual(comps.year, 2025)
        XCTAssertEqual(comps.month, 12)
    }

    // MARK: - birthdayPeople

    func testBirthdayPeople_findsCorrectPerson() {
        let p = makePerson(month: 3, day: 8)
        let result = CalendarViewLogic.birthdayPeople(inMonth: 3, onDay: 8, from: [p])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, p.id)
    }

    func testBirthdayPeople_emptyForWrongDay() {
        let p = makePerson(month: 3, day: 8)
        let result = CalendarViewLogic.birthdayPeople(inMonth: 3, onDay: 9, from: [p])
        XCTAssertTrue(result.isEmpty)
    }

    func testBirthdayPeople_excludesIsExcludedPeople() {
        let excluded = makePerson(month: 5, day: 15, isExcluded: true)
        let result = CalendarViewLogic.birthdayPeople(inMonth: 5, onDay: 15, from: [excluded])
        XCTAssertTrue(result.isEmpty)
    }

    func testBirthdayPeople_ignoresPeopleWithNoBirthday() {
        let p = makePerson() // nil month and day
        let result = CalendarViewLogic.birthdayPeople(inMonth: 1, onDay: 1, from: [p])
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - swipeDirection (issue #12)

    func testSwipeDirection_largeNegativeTranslation_returnsForward() {
        XCTAssertEqual(CalendarViewLogic.swipeDirection(from: -100), .forward)
    }

    func testSwipeDirection_largePositiveTranslation_returnsBackward() {
        XCTAssertEqual(CalendarViewLogic.swipeDirection(from: 100), .backward)
    }

    func testSwipeDirection_smallNegativeTranslation_returnsNone() {
        XCTAssertEqual(CalendarViewLogic.swipeDirection(from: -30), .none)
    }

    func testSwipeDirection_smallPositiveTranslation_returnsNone() {
        XCTAssertEqual(CalendarViewLogic.swipeDirection(from: 30), .none)
    }

    func testSwipeDirection_exactlyAtThreshold_returnsNone() {
        // translation == -50 is NOT < -50 so should be .none
        XCTAssertEqual(CalendarViewLogic.swipeDirection(from: -50), .none)
        XCTAssertEqual(CalendarViewLogic.swipeDirection(from: 50), .none)
    }

    func testSwipeDirection_justBeyondThreshold_returnsDirectional() {
        XCTAssertEqual(CalendarViewLogic.swipeDirection(from: -51), .forward)
        XCTAssertEqual(CalendarViewLogic.swipeDirection(from: 51), .backward)
    }

    func testSwipeDirection_zeroTranslation_returnsNone() {
        XCTAssertEqual(CalendarViewLogic.swipeDirection(from: 0), .none)
    }

    func testSwipeDirection_customThreshold_forward() {
        XCTAssertEqual(CalendarViewLogic.swipeDirection(from: -101, threshold: 100), .forward)
    }

    func testSwipeDirection_customThreshold_tooSmall_returnsNone() {
        XCTAssertEqual(CalendarViewLogic.swipeDirection(from: -99, threshold: 100), .none)
    }
}
