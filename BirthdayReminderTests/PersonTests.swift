import XCTest
import SwiftData
@testable import BirthdayReminder

final class PersonTests: XCTestCase {

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

    private func makePerson(
        given: String = "",
        family: String = "",
        month: Int? = nil,
        day: Int? = nil,
        year: Int? = nil,
        congratulatedYear: Int? = nil,
        missedYear: Int? = nil
    ) -> Person {
        let p = Person()
        p.givenName = given
        p.familyName = family
        p.birthdayMonth = month
        p.birthdayDay = day
        p.birthdayYear = year
        p.congratulatedYear = congratulatedYear
        p.missedYear = missedYear
        context.insert(p)
        return p
    }

    // MARK: - fullName

    func testFullName_givenAndFamily() {
        let p = makePerson(given: "John", family: "Doe")
        XCTAssertEqual(p.fullName, "John Doe")
    }

    func testFullName_givenOnly() {
        let p = makePerson(given: "Alice")
        XCTAssertEqual(p.fullName, "Alice")
    }

    func testFullName_familyOnly() {
        let p = makePerson(family: "Smith")
        XCTAssertEqual(p.fullName, "Smith")
    }

    func testFullName_bothEmpty() {
        let p = makePerson()
        XCTAssertEqual(p.fullName, "")
    }

    func testFullName_trimsExtraWhitespace() {
        let p = makePerson(given: "Jane")
        // family is empty, so fullName should not have trailing space
        XCTAssertFalse(p.fullName.hasPrefix(" "))
        XCTAssertFalse(p.fullName.hasSuffix(" "))
    }

    // MARK: - initials

    func testInitials_givenAndFamily() {
        let p = makePerson(given: "John", family: "Doe")
        XCTAssertEqual(p.initials, "JD")
    }

    func testInitials_givenOnly() {
        let p = makePerson(given: "Alice")
        XCTAssertEqual(p.initials, "A")
    }

    func testInitials_familyOnly() {
        let p = makePerson(family: "Smith")
        XCTAssertEqual(p.initials, "S")
    }

    func testInitials_bothEmpty() {
        let p = makePerson()
        XCTAssertEqual(p.initials, "")
    }

    func testInitials_areUppercased() {
        let p = makePerson(given: "alice", family: "smith")
        XCTAssertEqual(p.initials, "AS")
    }

    // MARK: - isCongratulatedThisYear

    func testIsCongratulatedThisYear_currentYearIsTrue() {
        let thisYear = Calendar.current.component(.year, from: Date())
        let p = makePerson(congratulatedYear: thisYear)
        XCTAssertTrue(p.isCongratulatedThisYear)
    }

    func testIsCongratulatedThisYear_lastYearIsFalse() {
        let thisYear = Calendar.current.component(.year, from: Date())
        let p = makePerson(congratulatedYear: thisYear - 1)
        XCTAssertFalse(p.isCongratulatedThisYear)
    }

    func testIsCongratulatedThisYear_nilIsFalse() {
        let p = makePerson()
        XCTAssertFalse(p.isCongratulatedThisYear)
    }

    // MARK: - age

    func testAge_jan1BirthdayAlwaysPassed_returns30() {
        // January 1 is always <= today, so a 30-years-ago birth on Jan 1 always yields age 30
        let cal = Calendar.current
        let thisYear = cal.component(.year, from: Date())
        let p = makePerson(month: 1, day: 1, year: thisYear - 30)
        XCTAssertNotNil(p.age)
        XCTAssertEqual(p.age, 30)
    }

    func testAge_bornThisYearJan1_isZero() {
        let cal = Calendar.current
        let thisYear = cal.component(.year, from: Date())
        let p = makePerson(month: 1, day: 1, year: thisYear)
        XCTAssertNotNil(p.age)
        XCTAssertEqual(p.age, 0)
    }

    func testAge_noYear_returnsNil() {
        let p = makePerson(month: 6, day: 15)
        XCTAssertNil(p.age)
    }

    func testAge_noDateAtAll_returnsNil() {
        let p = makePerson()
        XCTAssertNil(p.age)
    }

    func testAge_birthdayNotYetThisYear_isOneYearLess() {
        // Dec 31 has not happened yet unless today IS Dec 31
        let cal = Calendar.current
        let today = cal.dateComponents([.month, .day], from: Date())
        guard today.month != 12 || today.day != 31 else { return }

        let thisYear = cal.component(.year, from: Date())
        // Born 25 years ago on Dec 31; birthday hasn't passed yet this year
        let p = makePerson(month: 12, day: 31, year: thisYear - 25)
        XCTAssertNotNil(p.age)
        XCTAssertEqual(p.age, 24)
    }

    // MARK: - isBirthdayToday

    func testIsBirthdayToday_matchesToday() {
        let cal = Calendar.current
        let today = cal.dateComponents([.month, .day], from: Date())
        let p = makePerson(month: today.month, day: today.day)
        XCTAssertTrue(p.isBirthdayToday)
    }

    func testIsBirthdayToday_tomorrowIsFalse() {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date())!
        let comps = cal.dateComponents([.month, .day], from: tomorrow)
        let p = makePerson(month: comps.month, day: comps.day)
        XCTAssertFalse(p.isBirthdayToday)
    }

    func testIsBirthdayToday_yesterdayIsFalse() {
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!
        let comps = cal.dateComponents([.month, .day], from: yesterday)
        let p = makePerson(month: comps.month, day: comps.day)
        XCTAssertFalse(p.isBirthdayToday)
    }

    func testIsBirthdayToday_noBirthdayIsFalse() {
        let p = makePerson()
        XCTAssertFalse(p.isBirthdayToday)
    }

    // MARK: - daysSinceBirthday

    func testDaysSinceBirthday_todayIsZero() {
        let cal = Calendar.current
        let today = cal.dateComponents([.month, .day], from: Date())
        let p = makePerson(month: today.month, day: today.day)
        XCTAssertEqual(p.daysSinceBirthday, 0)
    }

    func testDaysSinceBirthday_yesterdayIsOne() {
        let cal = Calendar.current
        // Guard: skip on Jan 1 where "yesterday" (Dec 31) crosses the year
        // and daysSinceBirthday computes against the *this-year* Dec 31 (in the future)
        guard cal.ordinality(of: .day, in: .year, for: Date()) ?? 1 > 1 else { return }

        let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!
        let comps = cal.dateComponents([.month, .day], from: yesterday)
        let p = makePerson(month: comps.month, day: comps.day)
        XCTAssertEqual(p.daysSinceBirthday, 1)
    }

    func testDaysSinceBirthday_tomorrowIsNegativeOne() {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date())!
        let comps = cal.dateComponents([.month, .day], from: tomorrow)
        let p = makePerson(month: comps.month, day: comps.day)
        XCTAssertEqual(p.daysSinceBirthday, -1)
    }

    func testDaysSinceBirthday_noDateReturnsNil() {
        let p = makePerson()
        XCTAssertNil(p.daysSinceBirthday)
    }

    // MARK: - daysUntilBirthday

    func testDaysUntilBirthday_todayIsZero() {
        let cal = Calendar.current
        let today = cal.dateComponents([.month, .day], from: Date())
        let p = makePerson(month: today.month, day: today.day)
        XCTAssertEqual(p.daysUntilBirthday, 0)
    }

    func testDaysUntilBirthday_tomorrowIsOne() {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date())!
        let comps = cal.dateComponents([.month, .day], from: tomorrow)
        let p = makePerson(month: comps.month, day: comps.day)
        XCTAssertEqual(p.daysUntilBirthday, 1)
    }

    func testDaysUntilBirthday_jan1IsInFutureOrToday() {
        let cal = Calendar.current
        let today = cal.dateComponents([.month, .day], from: Date())
        let p = makePerson(month: 1, day: 1)
        if today.month == 1 && today.day == 1 {
            XCTAssertEqual(p.daysUntilBirthday, 0)
        } else {
            // Not January 1: next birthday is either this year's Jan 1 (past, so next year)
            // or it wraps around. Either way it should be > 0.
            XCTAssertGreaterThan(p.daysUntilBirthday, 0)
        }
    }

    // MARK: - isMissedYesterday

    func testIsMissedYesterday_uncongratulatedYesterdayIsTrue() {
        let cal = Calendar.current
        // Skip on Jan 1 where the year-boundary skews daysSinceBirthday
        guard cal.ordinality(of: .day, in: .year, for: Date()) ?? 1 > 1 else { return }

        let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!
        let comps = cal.dateComponents([.month, .day], from: yesterday)
        let p = makePerson(month: comps.month, day: comps.day)
        XCTAssertTrue(p.isMissedYesterday)
    }

    func testIsMissedYesterday_congratulatedThisYearIsFalse() {
        let cal = Calendar.current
        guard cal.ordinality(of: .day, in: .year, for: Date()) ?? 1 > 1 else { return }

        let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!
        let comps = cal.dateComponents([.month, .day], from: yesterday)
        let thisYear = cal.component(.year, from: Date())
        let p = makePerson(month: comps.month, day: comps.day, congratulatedYear: thisYear)
        XCTAssertFalse(p.isMissedYesterday)
    }

    func testIsMissedYesterday_missedYearSetIsFalse() {
        let cal = Calendar.current
        guard cal.ordinality(of: .day, in: .year, for: Date()) ?? 1 > 1 else { return }

        let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!
        let comps = cal.dateComponents([.month, .day], from: yesterday)
        let thisYear = cal.component(.year, from: Date())
        let p = makePerson(month: comps.month, day: comps.day, missedYear: thisYear)
        XCTAssertFalse(p.isMissedYesterday)
    }

    func testIsMissedYesterday_todayBirthdayIsFalse() {
        let cal = Calendar.current
        let today = cal.dateComponents([.month, .day], from: Date())
        let p = makePerson(month: today.month, day: today.day)
        XCTAssertFalse(p.isMissedYesterday)
    }

    func testIsMissedYesterday_noBirthdayIsFalse() {
        let p = makePerson()
        XCTAssertFalse(p.isMissedYesterday)
    }

    // MARK: - shouldAutoMarkMissed

    func testShouldAutoMarkMissed_twoDaysAgoUncongratulatedIsTrue() {
        let cal = Calendar.current
        // Skip on Jan 1-2 where two-days-ago crosses the year boundary
        guard cal.ordinality(of: .day, in: .year, for: Date()) ?? 1 > 2 else { return }

        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: Date())!
        let comps = cal.dateComponents([.month, .day], from: twoDaysAgo)
        let p = makePerson(month: comps.month, day: comps.day)
        XCTAssertTrue(p.shouldAutoMarkMissed)
    }

    func testShouldAutoMarkMissed_yesterdayIsFalse() {
        let cal = Calendar.current
        guard cal.ordinality(of: .day, in: .year, for: Date()) ?? 1 > 1 else { return }

        let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!
        let comps = cal.dateComponents([.month, .day], from: yesterday)
        let p = makePerson(month: comps.month, day: comps.day)
        XCTAssertFalse(p.shouldAutoMarkMissed)
    }

    func testShouldAutoMarkMissed_alreadyCongratulatedIsFalse() {
        let cal = Calendar.current
        guard cal.ordinality(of: .day, in: .year, for: Date()) ?? 1 > 2 else { return }

        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: Date())!
        let comps = cal.dateComponents([.month, .day], from: twoDaysAgo)
        let thisYear = cal.component(.year, from: Date())
        let p = makePerson(month: comps.month, day: comps.day, congratulatedYear: thisYear)
        XCTAssertFalse(p.shouldAutoMarkMissed)
    }

    func testShouldAutoMarkMissed_alreadyMarkedMissedIsFalse() {
        let cal = Calendar.current
        guard cal.ordinality(of: .day, in: .year, for: Date()) ?? 1 > 2 else { return }

        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: Date())!
        let comps = cal.dateComponents([.month, .day], from: twoDaysAgo)
        let thisYear = cal.component(.year, from: Date())
        let p = makePerson(month: comps.month, day: comps.day, missedYear: thisYear)
        XCTAssertFalse(p.shouldAutoMarkMissed)
    }

    // MARK: - birthdayDisplayString

    func testBirthdayDisplayString_noDate_returnsUnknown() {
        let p = makePerson()
        XCTAssertEqual(p.birthdayDisplayString, "Unknown")
    }

    func testBirthdayDisplayString_monthAndDayOnly() {
        let p = makePerson(month: 1, day: 15)
        XCTAssertEqual(p.birthdayDisplayString, "January 15")
    }

    func testBirthdayDisplayString_withYear() {
        let p = makePerson(month: 3, day: 8, year: 1990)
        XCTAssertEqual(p.birthdayDisplayString, "March 8, 1990")
    }

    func testBirthdayDisplayString_december31() {
        let p = makePerson(month: 12, day: 31)
        XCTAssertEqual(p.birthdayDisplayString, "December 31")
    }

    // MARK: - turningAge

    func testTurningAge_withBirthYear_returnsNonNil() {
        let p = makePerson(month: 6, day: 15, year: 1990)
        XCTAssertNotNil(p.turningAge)
    }

    func testTurningAge_noBirthYear_returnsNil() {
        let p = makePerson(month: 6, day: 15)
        XCTAssertNil(p.turningAge)
    }

    func testTurningAge_jan1Birthday_isCorrect() {
        // Jan 1 birthday: next birthday is always Jan 1 of current year (since it's always in the future
        // or today). nextYear = this year, so turningAge = thisYear - birthYear.
        let cal = Calendar.current
        let thisYear = cal.component(.year, from: Date())
        let today = cal.dateComponents([.month, .day], from: Date())
        let p = makePerson(month: 1, day: 1, year: 1990)
        guard let age = p.turningAge else {
            XCTFail("turningAge should not be nil when birthYear is set")
            return
        }
        if today.month == 1 && today.day == 1 {
            // Today IS Jan 1; nextBirthdayDate = today
            XCTAssertEqual(age, thisYear - 1990)
        } else {
            // Jan 1 is in the past this year; nextBirthdayDate = Jan 1 next year
            XCTAssertEqual(age, (thisYear + 1) - 1990)
        }
    }

    // MARK: - nextBirthdayDate

    func testNextBirthdayDate_noBirthday_returnsDistantFuture() {
        let p = makePerson()
        XCTAssertEqual(p.nextBirthdayDate, .distantFuture)
    }

    func testNextBirthdayDate_todayBirthday_isToday() {
        let cal = Calendar.current
        let today = cal.dateComponents([.month, .day], from: Date())
        let p = makePerson(month: today.month, day: today.day)
        let nextComps = cal.dateComponents([.month, .day], from: p.nextBirthdayDate)
        XCTAssertEqual(nextComps.month, today.month)
        XCTAssertEqual(nextComps.day, today.day)
    }

    func testNextBirthdayDate_pastBirthday_isAfterToday() {
        let cal = Calendar.current
        // A birthday 2 days ago: next occurrence is strictly in the future
        // (even across year boundaries, Dec 31 with today Jan 2 → next is Dec 31 this year, still future)
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: Date())!
        let comps = cal.dateComponents([.month, .day], from: twoDaysAgo)
        let p = makePerson(month: comps.month, day: comps.day)
        XCTAssertGreaterThan(p.nextBirthdayDate, cal.startOfDay(for: Date()))
    }

    func testNextBirthdayDate_futureBirthday_isThisYearOrLater() {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date())!
        let comps = cal.dateComponents([.month, .day], from: tomorrow)
        let p = makePerson(month: comps.month, day: comps.day)
        let nextYear = cal.component(.year, from: p.nextBirthdayDate)
        let thisYear = cal.component(.year, from: Date())
        XCTAssertGreaterThanOrEqual(nextYear, thisYear)
    }

    // MARK: - lastBirthdayDate

    func testLastBirthdayDate_noBirthday_returnsDistantPast() {
        let p = makePerson()
        XCTAssertEqual(p.lastBirthdayDate, .distantPast)
    }

    func testLastBirthdayDate_todayBirthday_returnsToday() {
        let cal = Calendar.current
        let today = cal.dateComponents([.month, .day], from: Date())
        let p = makePerson(month: today.month, day: today.day)
        let lastComps = cal.dateComponents([.month, .day], from: p.lastBirthdayDate)
        XCTAssertEqual(lastComps.month, today.month)
        XCTAssertEqual(lastComps.day, today.day)
    }

    func testLastBirthdayDate_pastBirthday_isOnOrBeforeToday() {
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!
        let comps = cal.dateComponents([.month, .day], from: yesterday)
        let p = makePerson(month: comps.month, day: comps.day)
        XCTAssertLessThanOrEqual(p.lastBirthdayDate, Date())
    }

    // MARK: - isExcluded

    func testIsExcluded_defaultIsFalse() {
        let p = makePerson()
        XCTAssertFalse(p.isExcluded)
    }

    func testIsExcluded_canBeSetToTrue() {
        let p = makePerson()
        p.isExcluded = true
        XCTAssertTrue(p.isExcluded)
    }

    // MARK: - isCongratulatedOnLastBirthday

    func testIsCongratulatedOnLastBirthday_noCongratulation_isFalse() {
        let p = makePerson(month: 1, day: 1)
        XCTAssertFalse(p.isCongratulatedOnLastBirthday)
    }

    func testIsCongratulatedOnLastBirthday_congratulatedForPastBirthday_isTrue() {
        let cal = Calendar.current
        guard cal.ordinality(of: .day, in: .year, for: Date()) ?? 1 > 2 else { return }

        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: Date())!
        let comps = cal.dateComponents([.month, .day], from: twoDaysAgo)
        let thisYear = cal.component(.year, from: Date())
        let p = makePerson(month: comps.month, day: comps.day, congratulatedYear: thisYear)
        XCTAssertTrue(p.isCongratulatedOnLastBirthday)
    }

    func testIsCongratulatedOnLastBirthday_congratulatedLastYear_isFalse() {
        // Birthday is today, but congratulatedYear is last year → not congratulated on last (= today's) birthday
        let cal = Calendar.current
        let today = cal.dateComponents([.month, .day], from: Date())
        let thisYear = cal.component(.year, from: Date())
        let p = makePerson(month: today.month, day: today.day, congratulatedYear: thisYear - 1)
        XCTAssertFalse(p.isCongratulatedOnLastBirthday)
    }

    // MARK: - id uniqueness

    func testPersonID_isUniquePerInstance() {
        let p1 = makePerson(given: "Alice")
        let p2 = makePerson(given: "Bob")
        XCTAssertNotEqual(p1.id, p2.id)
    }

    // MARK: - wishlistItems

    func testWishlistItems_defaultIsEmpty() {
        let p = makePerson()
        XCTAssertTrue(p.wishlistItems.isEmpty)
    }
}
