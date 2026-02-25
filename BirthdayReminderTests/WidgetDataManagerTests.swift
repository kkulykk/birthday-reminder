import XCTest
@testable import BirthdayReminder

final class WidgetDataManagerTests: XCTestCase {

    // MARK: - WidgetBirthday properties

    func testWidgetBirthday_properties() {
        let id = UUID()
        let birthday = WidgetBirthday(id: id, name: "Alice Smith", daysUntil: 3, isBirthdayToday: false, monthDay: "Mar 8")
        XCTAssertEqual(birthday.id, id)
        XCTAssertEqual(birthday.name, "Alice Smith")
        XCTAssertEqual(birthday.daysUntil, 3)
        XCTAssertFalse(birthday.isBirthdayToday)
        XCTAssertEqual(birthday.monthDay, "Mar 8")
    }

    func testWidgetBirthday_isBirthdayToday_true() {
        let birthday = WidgetBirthday(id: UUID(), name: "Bob", daysUntil: 0, isBirthdayToday: true, monthDay: "Feb 24")
        XCTAssertTrue(birthday.isBirthdayToday)
        XCTAssertEqual(birthday.daysUntil, 0)
    }

    func testWidgetBirthday_isBirthdayToday_false() {
        let birthday = WidgetBirthday(id: UUID(), name: "Carol", daysUntil: 5, isBirthdayToday: false, monthDay: "Mar 1")
        XCTAssertFalse(birthday.isBirthdayToday)
        XCTAssertGreaterThan(birthday.daysUntil, 0)
    }

    func testWidgetBirthday_uniqueIDs() {
        let b1 = WidgetBirthday(id: UUID(), name: "A", daysUntil: 1, isBirthdayToday: false, monthDay: "Jan 1")
        let b2 = WidgetBirthday(id: UUID(), name: "B", daysUntil: 2, isBirthdayToday: false, monthDay: "Jan 2")
        XCTAssertNotEqual(b1.id, b2.id)
    }

    // MARK: - WidgetBirthday Codable

    func testWidgetBirthday_codableRoundTrip() throws {
        let original = WidgetBirthday(
            id: UUID(),
            name: "Charlie Brown",
            daysUntil: 7,
            isBirthdayToday: false,
            monthDay: "Dec 31"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WidgetBirthday.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.daysUntil, original.daysUntil)
        XCTAssertEqual(decoded.isBirthdayToday, original.isBirthdayToday)
        XCTAssertEqual(decoded.monthDay, original.monthDay)
    }

    func testWidgetBirthday_codable_isBirthdayTodayTrue() throws {
        let original = WidgetBirthday(id: UUID(), name: "Today Person", daysUntil: 0, isBirthdayToday: true, monthDay: "Feb 24")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WidgetBirthday.self, from: data)
        XCTAssertTrue(decoded.isBirthdayToday)
        XCTAssertEqual(decoded.daysUntil, 0)
    }

    func testWidgetBirthday_arrayRoundTrip() throws {
        let birthdays = [
            WidgetBirthday(id: UUID(), name: "Alice", daysUntil: 0, isBirthdayToday: true, monthDay: "Feb 24"),
            WidgetBirthday(id: UUID(), name: "Bob", daysUntil: 3, isBirthdayToday: false, monthDay: "Feb 27"),
            WidgetBirthday(id: UUID(), name: "Carol", daysUntil: 7, isBirthdayToday: false, monthDay: "Mar 3"),
        ]
        let data = try JSONEncoder().encode(birthdays)
        let decoded = try JSONDecoder().decode([WidgetBirthday].self, from: data)
        XCTAssertEqual(decoded.count, 3)
        XCTAssertEqual(decoded[0].name, "Alice")
        XCTAssertTrue(decoded[0].isBirthdayToday)
        XCTAssertEqual(decoded[1].daysUntil, 3)
        XCTAssertEqual(decoded[2].monthDay, "Mar 3")
    }

    func testWidgetBirthday_emptyArrayRoundTrip() throws {
        let birthdays: [WidgetBirthday] = []
        let data = try JSONEncoder().encode(birthdays)
        let decoded = try JSONDecoder().decode([WidgetBirthday].self, from: data)
        XCTAssertTrue(decoded.isEmpty)
    }

    // MARK: - WidgetDataManager constants

    func testWidgetDataManager_suiteName() {
        XCTAssertEqual(WidgetDataManager.suiteName, "group.kkulykk.BirthdayReminder")
    }

    func testWidgetDataManager_key() {
        XCTAssertEqual(WidgetDataManager.key, "widgetUpcomingBirthdays")
    }

    // MARK: - WidgetDataManager.load

    func testWidgetDataManager_loadWithNoData_returnsEmpty() {
        // Remove any previously stored data, then verify load returns []
        UserDefaults(suiteName: WidgetDataManager.suiteName)?.removeObject(forKey: WidgetDataManager.key)
        let result = WidgetDataManager.load()
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - WidgetDataManager save / load round-trip
    // These tests guard against the App Group suite being unavailable in CI.

    func testWidgetDataManager_saveAndLoad_roundTrip() {
        guard UserDefaults(suiteName: WidgetDataManager.suiteName) != nil else { return }
        defer { UserDefaults(suiteName: WidgetDataManager.suiteName)?.removeObject(forKey: WidgetDataManager.key) }

        let birthdays = [
            WidgetBirthday(id: UUID(), name: "Test Person", daysUntil: 2, isBirthdayToday: false, monthDay: "Feb 26"),
        ]
        WidgetDataManager.save(birthdays)
        let loaded = WidgetDataManager.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].name, "Test Person")
        XCTAssertEqual(loaded[0].daysUntil, 2)
        XCTAssertEqual(loaded[0].monthDay, "Feb 26")
    }

    func testWidgetDataManager_saveEmptyArray_loadsEmpty() {
        guard UserDefaults(suiteName: WidgetDataManager.suiteName) != nil else { return }
        defer { UserDefaults(suiteName: WidgetDataManager.suiteName)?.removeObject(forKey: WidgetDataManager.key) }

        WidgetDataManager.save([])
        let loaded = WidgetDataManager.load()
        XCTAssertTrue(loaded.isEmpty)
    }

    func testWidgetDataManager_saveMultiple_preservesOrder() {
        guard UserDefaults(suiteName: WidgetDataManager.suiteName) != nil else { return }
        defer { UserDefaults(suiteName: WidgetDataManager.suiteName)?.removeObject(forKey: WidgetDataManager.key) }

        let birthdays = [
            WidgetBirthday(id: UUID(), name: "First", daysUntil: 0, isBirthdayToday: true, monthDay: "Feb 24"),
            WidgetBirthday(id: UUID(), name: "Second", daysUntil: 3, isBirthdayToday: false, monthDay: "Feb 27"),
            WidgetBirthday(id: UUID(), name: "Third", daysUntil: 7, isBirthdayToday: false, monthDay: "Mar 3"),
        ]
        WidgetDataManager.save(birthdays)
        let loaded = WidgetDataManager.load()
        XCTAssertEqual(loaded.count, 3)
        XCTAssertEqual(loaded[0].name, "First")
        XCTAssertEqual(loaded[1].name, "Second")
        XCTAssertEqual(loaded[2].name, "Third")
    }

    func testWidgetDataManager_overwritesPreviousSave() {
        guard UserDefaults(suiteName: WidgetDataManager.suiteName) != nil else { return }
        defer { UserDefaults(suiteName: WidgetDataManager.suiteName)?.removeObject(forKey: WidgetDataManager.key) }

        let first = [WidgetBirthday(id: UUID(), name: "Old", daysUntil: 5, isBirthdayToday: false, monthDay: "Mar 1")]
        WidgetDataManager.save(first)

        let second = [
            WidgetBirthday(id: UUID(), name: "New1", daysUntil: 1, isBirthdayToday: false, monthDay: "Feb 25"),
            WidgetBirthday(id: UUID(), name: "New2", daysUntil: 2, isBirthdayToday: false, monthDay: "Feb 26"),
        ]
        WidgetDataManager.save(second)

        let loaded = WidgetDataManager.load()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].name, "New1")
        XCTAssertEqual(loaded[1].name, "New2")
    }
}
