import XCTest
import SwiftData
import Contacts
@testable import BirthdayReminder

final class ContactImportTests: XCTestCase {

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

    private func makePerson(month: Int? = nil, day: Int? = nil, year: Int? = nil) -> Person {
        let p = Person()
        p.birthdayMonth = month
        p.birthdayDay = day
        p.birthdayYear = year
        context.insert(p)
        return p
    }

    private func makeContact(month: Int?, day: Int?, year: Int? = nil) -> CNMutableContact {
        let contact = CNMutableContact()
        if let month, let day {
            var comps = DateComponents()
            comps.month = month
            comps.day = day
            comps.year = year
            contact.birthday = comps
        }
        return contact
    }

    // MARK: - applyContactFields: birthday sync

    func testApplyContactFields_updatesMonthAndDay() {
        let person = makePerson(month: 3, day: 8)
        let contact = makeContact(month: 5, day: 15)

        ContactsService.applyContactFields(contact, to: person)

        XCTAssertEqual(person.birthdayMonth, 5)
        XCTAssertEqual(person.birthdayDay, 15)
    }

    func testApplyContactFields_updatesYear() {
        let person = makePerson(month: 1, day: 1, year: 1990)
        let contact = makeContact(month: 1, day: 1, year: 1995)

        ContactsService.applyContactFields(contact, to: person)

        XCTAssertEqual(person.birthdayYear, 1995)
    }

    func testApplyContactFields_clearsYearWhenNilInContact() {
        let person = makePerson(month: 6, day: 20, year: 1988)
        let contact = makeContact(month: 6, day: 20, year: nil) // no year

        ContactsService.applyContactFields(contact, to: person)

        XCTAssertNil(person.birthdayYear)
    }

    func testApplyContactFields_clearsFieldsWhenContactHasNoBirthday() {
        let person = makePerson(month: 4, day: 10, year: 1985)
        let contact = makeContact(month: nil, day: nil) // no birthday set

        ContactsService.applyContactFields(contact, to: person)

        XCTAssertNil(person.birthdayMonth)
        XCTAssertNil(person.birthdayDay)
        XCTAssertNil(person.birthdayYear)
    }

    func testApplyContactFields_preservesOtherPersonFields() {
        let person = makePerson(month: 3, day: 8)
        person.givenName = "Alice"
        person.familyName = "Smith"
        let contact = makeContact(month: 7, day: 4)

        ContactsService.applyContactFields(contact, to: person)

        // Birthday updated
        XCTAssertEqual(person.birthdayMonth, 7)
        XCTAssertEqual(person.birthdayDay, 4)
        // Other fields untouched
        XCTAssertEqual(person.givenName, "Alice")
        XCTAssertEqual(person.familyName, "Smith")
    }
}
