import XCTest
import SwiftData
@testable import BirthdayReminder

final class SearchTests: XCTestCase {

    // MARK: - Setup

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
        congratulatedYear: Int? = nil,
        missedYear: Int? = nil
    ) -> Person {
        let p = Person()
        p.givenName = given
        p.familyName = family
        p.birthdayMonth = month
        p.birthdayDay = day
        p.congratulatedYear = congratulatedYear
        p.missedYear = missedYear
        context.insert(p)
        return p
    }

    // MARK: - filterByQuery: empty query

    func testFilterByQuery_emptyQuery_returnsAllPeople() {
        let p1 = makePerson(given: "Alice", family: "Smith")
        let p2 = makePerson(given: "Bob", family: "Jones")
        let result = BirthdayListLogic.filterByQuery("", from: [p1, p2])
        XCTAssertEqual(result.count, 2)
    }

    func testFilterByQuery_emptyQuery_emptyInput_returnsEmpty() {
        let result = BirthdayListLogic.filterByQuery("", from: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testFilterByQuery_emptyQuery_preservesInputOrder() {
        let p1 = makePerson(given: "Alice")
        let p2 = makePerson(given: "Bob")
        let result = BirthdayListLogic.filterByQuery("", from: [p1, p2])
        XCTAssertEqual(result[0].id, p1.id)
        XCTAssertEqual(result[1].id, p2.id)
    }

    // MARK: - filterByQuery: matching by name

    func testFilterByQuery_matchesGivenName() {
        let alice = makePerson(given: "Alice", family: "Smith")
        let bob = makePerson(given: "Bob", family: "Jones")
        let result = BirthdayListLogic.filterByQuery("Alice", from: [alice, bob])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, alice.id)
    }

    func testFilterByQuery_matchesFamilyName() {
        let alice = makePerson(given: "Alice", family: "Smith")
        let bob = makePerson(given: "Bob", family: "Jones")
        let result = BirthdayListLogic.filterByQuery("Jones", from: [alice, bob])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, bob.id)
    }

    func testFilterByQuery_matchesFullName() {
        let alice = makePerson(given: "Alice", family: "Smith")
        let result = BirthdayListLogic.filterByQuery("Alice Smith", from: [alice])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, alice.id)
    }

    func testFilterByQuery_partialGivenNameMatch() {
        let alice = makePerson(given: "Alice", family: "Smith")
        let result = BirthdayListLogic.filterByQuery("Ali", from: [alice])
        XCTAssertEqual(result.count, 1)
    }

    func testFilterByQuery_partialFamilyNameMatch() {
        let alice = makePerson(given: "Alice", family: "Smith")
        let result = BirthdayListLogic.filterByQuery("mit", from: [alice])
        XCTAssertEqual(result.count, 1)
    }

    func testFilterByQuery_singleCharacterMatch() {
        let alice = makePerson(given: "Alice", family: "Smith")
        let result = BirthdayListLogic.filterByQuery("A", from: [alice])
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - filterByQuery: case insensitivity

    func testFilterByQuery_caseInsensitive_lowercaseQuery() {
        let alice = makePerson(given: "Alice", family: "Smith")
        let result = BirthdayListLogic.filterByQuery("alice", from: [alice])
        XCTAssertEqual(result.count, 1)
    }

    func testFilterByQuery_caseInsensitive_uppercaseQuery() {
        let alice = makePerson(given: "Alice", family: "Smith")
        let result = BirthdayListLogic.filterByQuery("ALICE", from: [alice])
        XCTAssertEqual(result.count, 1)
    }

    func testFilterByQuery_caseInsensitive_mixedCaseQuery() {
        let alice = makePerson(given: "Alice", family: "Smith")
        let result = BirthdayListLogic.filterByQuery("aLiCe", from: [alice])
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - filterByQuery: non-matching

    func testFilterByQuery_noMatch_returnsEmpty() {
        let alice = makePerson(given: "Alice", family: "Smith")
        let result = BirthdayListLogic.filterByQuery("xyz", from: [alice])
        XCTAssertTrue(result.isEmpty)
    }

    func testFilterByQuery_nonMatchingOnEmptyPeople_returnsEmpty() {
        let result = BirthdayListLogic.filterByQuery("Alice", from: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testFilterByQuery_queryMatchesSomeButNotAll() {
        let alice = makePerson(given: "Alice", family: "Smith")
        let bob = makePerson(given: "Bob", family: "Jones")
        let carol = makePerson(given: "Carol", family: "White")
        let result = BirthdayListLogic.filterByQuery("Alice", from: [alice, bob, carol])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, alice.id)
    }

    // MARK: - filterByQuery: multiple results

    func testFilterByQuery_multipleMatchesReturned() {
        let alice = makePerson(given: "Alice", family: "Smith")
        let alicia = makePerson(given: "Alicia", family: "Jones")
        let bob = makePerson(given: "Bob", family: "Brown")
        let result = BirthdayListLogic.filterByQuery("Ali", from: [alice, alicia, bob])
        XCTAssertEqual(result.count, 2)
        let ids = result.map(\.id)
        XCTAssertTrue(ids.contains(alice.id))
        XCTAssertTrue(ids.contains(alicia.id))
        XCTAssertFalse(ids.contains(bob.id))
    }

    func testFilterByQuery_sharedFamilyName_returnsAll() {
        let john = makePerson(given: "John", family: "Smith")
        let jane = makePerson(given: "Jane", family: "Smith")
        let result = BirthdayListLogic.filterByQuery("Smith", from: [john, jane])
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - filterByQuery: sort order

    func testFilterByQuery_sortedByNextBirthdayDate_earlierFirst() {
        let cal = Calendar.current
        // Person A: birthday tomorrow
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date())!
        let tomorrowComps = cal.dateComponents([.month, .day], from: tomorrow)
        let personA = makePerson(given: "Anna", family: "Smith",
                                 month: tomorrowComps.month, day: tomorrowComps.day)

        // Person B: birthday 3 days from now
        let threeDays = cal.date(byAdding: .day, value: 3, to: Date())!
        let threeDaysComps = cal.dateComponents([.month, .day], from: threeDays)
        let personB = makePerson(given: "Beth", family: "Smith",
                                 month: threeDaysComps.month, day: threeDaysComps.day)

        // Provide input in reverse order to verify sort is applied
        let result = BirthdayListLogic.filterByQuery("Smith", from: [personB, personA])
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.id, personA.id)
        XCTAssertEqual(result.last?.id, personB.id)
    }

    func testFilterByQuery_noBirthdaySortedToEnd() {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date())!
        let tomorrowComps = cal.dateComponents([.month, .day], from: tomorrow)
        let withBirthday = makePerson(given: "Anna", family: "Smith",
                                      month: tomorrowComps.month, day: tomorrowComps.day)
        let noBirthday = makePerson(given: "Beth", family: "Smith")  // distantFuture

        let result = BirthdayListLogic.filterByQuery("Smith", from: [noBirthday, withBirthday])
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.id, withBirthday.id)
        XCTAssertEqual(result.last?.id, noBirthday.id)
    }

    // MARK: - filterByQuery: givenName-only / familyName-only persons

    func testFilterByQuery_givenNameOnlyPerson_matchesByGivenName() {
        let p = makePerson(given: "Maria")
        let result = BirthdayListLogic.filterByQuery("Maria", from: [p])
        XCTAssertEqual(result.count, 1)
    }

    func testFilterByQuery_familyNameOnlyPerson_matchesByFamilyName() {
        let p = makePerson(family: "Garcia")
        let result = BirthdayListLogic.filterByQuery("Garcia", from: [p])
        XCTAssertEqual(result.count, 1)
    }

    func testFilterByQuery_personWithNoName_doesNotMatchNonEmptyQuery() {
        let p = makePerson()  // fullName = ""
        let result = BirthdayListLogic.filterByQuery("Alice", from: [p])
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - tileStyle: today

    func testTileStyle_birthdayToday_returnsToday() {
        let cal = Calendar.current
        let today = cal.dateComponents([.month, .day], from: Date())
        let p = makePerson(month: today.month, day: today.day)
        XCTAssertEqual(BirthdayListLogic.tileStyle(for: p), .today)
    }

    func testTileStyle_birthdayToday_takesTodayPriorityOverOtherStates() {
        // Even if congratulatedYear matches this year, isBirthdayToday still triggers .today
        let cal = Calendar.current
        let today = cal.dateComponents([.month, .day], from: Date())
        let thisYear = cal.component(.year, from: Date())
        let p = makePerson(month: today.month, day: today.day, congratulatedYear: thisYear)
        // isBirthdayToday is true regardless of congratulation status
        XCTAssertEqual(BirthdayListLogic.tileStyle(for: p), .today)
    }

    // MARK: - tileStyle: missed

    func testTileStyle_missedYesterday_returnsMissed() {
        let cal = Calendar.current
        // Skip on Jan 1 where yesterday crosses the year boundary
        guard cal.ordinality(of: .day, in: .year, for: Date()) ?? 1 > 1 else { return }

        let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!
        let comps = cal.dateComponents([.month, .day], from: yesterday)
        let p = makePerson(month: comps.month, day: comps.day)
        XCTAssertEqual(BirthdayListLogic.tileStyle(for: p), .missed)
    }

    // MARK: - tileStyle: past

    func testTileStyle_twoDaysAgoBirthday_returnsPast() {
        let cal = Calendar.current
        guard cal.ordinality(of: .day, in: .year, for: Date()) ?? 1 > 2 else { return }

        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: Date())!
        let comps = cal.dateComponents([.month, .day], from: twoDaysAgo)
        let p = makePerson(month: comps.month, day: comps.day)
        XCTAssertEqual(BirthdayListLogic.tileStyle(for: p), .past)
    }

    func testTileStyle_manyDaysAgoBirthday_returnsPast() {
        let cal = Calendar.current
        guard cal.ordinality(of: .day, in: .year, for: Date()) ?? 1 > 30 else { return }

        let thirtyDaysAgo = cal.date(byAdding: .day, value: -30, to: Date())!
        let comps = cal.dateComponents([.month, .day], from: thirtyDaysAgo)
        let p = makePerson(month: comps.month, day: comps.day)
        XCTAssertEqual(BirthdayListLogic.tileStyle(for: p), .past)
    }

    // MARK: - tileStyle: upcoming

    func testTileStyle_tomorrowBirthday_returnsUpcoming() {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date())!
        let comps = cal.dateComponents([.month, .day], from: tomorrow)
        let p = makePerson(month: comps.month, day: comps.day)
        XCTAssertEqual(BirthdayListLogic.tileStyle(for: p), .upcoming)
    }

    func testTileStyle_farFutureBirthday_returnsUpcoming() {
        let cal = Calendar.current
        let future = cal.date(byAdding: .day, value: 60, to: Date())!
        let comps = cal.dateComponents([.month, .day], from: future)
        let p = makePerson(month: comps.month, day: comps.day)
        XCTAssertEqual(BirthdayListLogic.tileStyle(for: p), .upcoming)
    }

    func testTileStyle_noBirthdaySet_returnsUpcoming() {
        // daysSinceBirthday returns nil → (nil ?? -1) = -1, not > 0
        // isBirthdayToday = false, isMissedYesterday = false
        let p = makePerson()
        XCTAssertEqual(BirthdayListLogic.tileStyle(for: p), .upcoming)
    }
}
