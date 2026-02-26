import XCTest
@testable import BirthdayReminder

// Tests for widget logic extracted into WidgetDataManager (Shared, compiled into main app):
//   - WidgetDataManager.widgetSectionLabel  (fixes issue #10)
//   - WidgetDataManager.adjustedBirthdays   (fixes issue #9)

// MARK: - widgetSectionLabel (issue #10)

final class WidgetSectionLabelTests: XCTestCase {

    private func birthday(daysUntil: Int, isToday: Bool) -> WidgetBirthday {
        WidgetBirthday(id: UUID(), name: "Person", daysUntil: daysUntil, isBirthdayToday: isToday, monthDay: "Jan 1")
    }

    func testWidgetSectionLabel_emptyNearest_returnsNoneThisWeek() {
        XCTAssertEqual(WidgetDataManager.widgetSectionLabel(nearest: []), "None this week")
    }

    func testWidgetSectionLabel_birthdayToday_returnsBirthday() {
        XCTAssertEqual(WidgetDataManager.widgetSectionLabel(nearest: [birthday(daysUntil: 0, isToday: true)]), "Birthday")
    }

    func testWidgetSectionLabel_upcomingBirthday_returnsUpcoming() {
        XCTAssertEqual(WidgetDataManager.widgetSectionLabel(nearest: [birthday(daysUntil: 3, isToday: false)]), "Upcoming")
    }

    func testWidgetSectionLabel_multipleTodayBirthdays_returnsBirthday() {
        let b1 = birthday(daysUntil: 0, isToday: true)
        let b2 = birthday(daysUntil: 0, isToday: true)
        XCTAssertEqual(WidgetDataManager.widgetSectionLabel(nearest: [b1, b2]), "Birthday")
    }

    func testWidgetSectionLabel_multipleUpcomingBirthdays_returnsUpcoming() {
        let b1 = birthday(daysUntil: 2, isToday: false)
        let b2 = birthday(daysUntil: 2, isToday: false)
        XCTAssertEqual(WidgetDataManager.widgetSectionLabel(nearest: [b1, b2]), "Upcoming")
    }
}

// MARK: - adjustedBirthdays (issue #9)

final class AdjustedBirthdaysTests: XCTestCase {

    private func stored(daysUntil: Int, isToday: Bool = false, name: String = "P") -> WidgetBirthday {
        WidgetBirthday(id: UUID(), name: name, daysUntil: daysUntil, isBirthdayToday: isToday, monthDay: "Jan 1")
    }

    // MARK: Day-0 pass-through

    func testAdjustedBirthdays_offset0_preservesBirthdayInWindow() {
        let result = WidgetDataManager.adjustedBirthdays(from: [stored(daysUntil: 3)], dayOffset: 0)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].daysUntil, 3)
    }

    func testAdjustedBirthdays_offset0_daysUntil7_included() {
        let result = WidgetDataManager.adjustedBirthdays(from: [stored(daysUntil: 7)], dayOffset: 0)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].daysUntil, 7)
    }

    func testAdjustedBirthdays_offset0_daysUntil8_excluded() {
        // 8-day birthday is not in the 7-day window for day 0
        let result = WidgetDataManager.adjustedBirthdays(from: [stored(daysUntil: 8)], dayOffset: 0)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: daysUntil decrement

    func testAdjustedBirthdays_offset1_decrementsDaysUntil() {
        let result = WidgetDataManager.adjustedBirthdays(from: [stored(daysUntil: 5)], dayOffset: 1)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].daysUntil, 4)
    }

    func testAdjustedBirthdays_offset3_decrementsDaysUntilBy3() {
        let result = WidgetDataManager.adjustedBirthdays(from: [stored(daysUntil: 5)], dayOffset: 3)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].daysUntil, 2)
    }

    // MARK: isBirthdayToday flag

    func testAdjustedBirthdays_adjustedDays0_setsisBirthdayToday() {
        // Birthday 3 days away, viewed from day 3 offset → adjustedDays = 0
        let result = WidgetDataManager.adjustedBirthdays(from: [stored(daysUntil: 3)], dayOffset: 3)
        XCTAssertEqual(result.first?.daysUntil, 0)
        XCTAssertTrue(result.first?.isBirthdayToday ?? false)
    }

    func testAdjustedBirthdays_adjustedDays1_notBirthdayToday() {
        let result = WidgetDataManager.adjustedBirthdays(from: [stored(daysUntil: 3)], dayOffset: 2)
        XCTAssertEqual(result.first?.daysUntil, 1)
        XCTAssertFalse(result.first?.isBirthdayToday ?? true)
    }

    // MARK: Negative daysUntil

    func testAdjustedBirthdays_pastBirthday_excluded() {
        // Birthday 2 days away, viewed from day 3 → adjustedDays = -1
        let result = WidgetDataManager.adjustedBirthdays(from: [stored(daysUntil: 2)], dayOffset: 3)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: 7-day window boundary

    func testAdjustedBirthdays_offset1_daysUntil8_included() {
        // daysUntil=8, offset=1 → adjustedDays=7, within window
        let result = WidgetDataManager.adjustedBirthdays(from: [stored(daysUntil: 8)], dayOffset: 1)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].daysUntil, 7)
    }

    func testAdjustedBirthdays_offset1_daysUntil9_excluded() {
        // daysUntil=9, offset=1 → adjustedDays=8, outside window
        let result = WidgetDataManager.adjustedBirthdays(from: [stored(daysUntil: 9)], dayOffset: 1)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: Multiple birthdays

    func testAdjustedBirthdays_multipleBirthdays_allAdjusted() {
        let stored = [
            self.stored(daysUntil: 1, name: "A"),
            self.stored(daysUntil: 4, name: "B"),
            self.stored(daysUntil: 7, name: "C"),
        ]
        let result = WidgetDataManager.adjustedBirthdays(from: stored, dayOffset: 1)
        XCTAssertEqual(result.count, 3)
        let days = result.map { $0.daysUntil }.sorted()
        XCTAssertEqual(days, [0, 3, 6])
    }

    func testAdjustedBirthdays_mixedWindow_onlyIncludesInWindow() {
        let stored = [
            self.stored(daysUntil: 2, name: "In"),      // adjustedDays@offset3 = -1 → excluded
            self.stored(daysUntil: 5, name: "Also"),    // adjustedDays@offset3 = 2 → included
            self.stored(daysUntil: 11, name: "Far"),    // adjustedDays@offset3 = 8 → excluded
        ]
        let result = WidgetDataManager.adjustedBirthdays(from: stored, dayOffset: 3)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "Also")
    }

    // MARK: ID and name preservation

    func testAdjustedBirthdays_preservesIDAndName() {
        let id = UUID()
        let stored = WidgetBirthday(id: id, name: "Alice", daysUntil: 3, isBirthdayToday: false, monthDay: "Mar 8")
        let result = WidgetDataManager.adjustedBirthdays(from: [stored], dayOffset: 1)
        XCTAssertEqual(result.first?.id, id)
        XCTAssertEqual(result.first?.name, "Alice")
        XCTAssertEqual(result.first?.monthDay, "Mar 8")
    }

    func testAdjustedBirthdays_emptyInput_returnsEmpty() {
        let result = WidgetDataManager.adjustedBirthdays(from: [], dayOffset: 0)
        XCTAssertTrue(result.isEmpty)
    }
}
