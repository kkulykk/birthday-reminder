import XCTest
import Contacts
import SwiftData
@testable import BirthdayReminder

// MARK: - MockContactStore

final class MockContactStore: @unchecked Sendable, ContactStoreProtocol {
    var stubbedGranted = true
    var stubbedAccessError: Error? = nil
    var stubbedContacts: [CNContact] = []
    var stubbedEnumerateError: Error? = nil

    func requestAccess(for entityType: CNEntityType, completionHandler: @escaping @Sendable (Bool, Error?) -> Void) {
        if let error = stubbedAccessError {
            completionHandler(false, error)
        } else {
            completionHandler(stubbedGranted, nil)
        }
    }

    func enumerateContacts(with fetchRequest: CNContactFetchRequest, usingBlock block: @escaping (CNContact, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        if let error = stubbedEnumerateError { throw error }
        for contact in stubbedContacts {
            var stop: ObjCBool = false
            withUnsafeMutablePointer(to: &stop) { ptr in
                block(contact, ptr)
            }
        }
    }
}

// MARK: - ContactsServiceTests

final class ContactsServiceTests: XCTestCase {

    private var mockStore: MockContactStore!
    private var service: ContactsService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        mockStore = MockContactStore()
        service = ContactsService(store: mockStore)
    }

    override func tearDownWithError() throws {
        service = nil
        mockStore = nil
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func makeContact(withBirthday: Bool, given: String = "Test") -> CNMutableContact {
        let c = CNMutableContact()
        c.givenName = given
        if withBirthday {
            var comps = DateComponents()
            comps.month = 6
            comps.day = 15
            c.birthday = comps
        }
        return c
    }

    // MARK: - requestPermission

    func testRequestPermission_granted_returnsTrue() async throws {
        mockStore.stubbedGranted = true
        let result = try await service.requestPermission()
        XCTAssertTrue(result)
    }

    func testRequestPermission_denied_returnsFalse() async throws {
        mockStore.stubbedGranted = false
        let result = try await service.requestPermission()
        XCTAssertFalse(result)
    }

    func testRequestPermission_storeError_throws() async {
        let expectedError = NSError(domain: "CNErrorDomain", code: 100)
        mockStore.stubbedAccessError = expectedError
        do {
            _ = try await service.requestPermission()
            XCTFail("Expected error to be thrown")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "CNErrorDomain")
            XCTAssertEqual(error.code, 100)
        }
    }

    // MARK: - fetchBirthdayContacts

    func testFetchBirthdayContacts_returnsContactsWithBirthday() async throws {
        mockStore.stubbedContacts = [
            makeContact(withBirthday: true, given: "Alice"),
            makeContact(withBirthday: true, given: "Bob"),
        ]
        let result = try await service.fetchBirthdayContacts()
        XCTAssertEqual(result.count, 2)
    }

    func testFetchBirthdayContacts_filtersOutContactsWithoutBirthday() async throws {
        mockStore.stubbedContacts = [
            makeContact(withBirthday: true, given: "Alice"),
            makeContact(withBirthday: false, given: "NoBirthday"),
        ]
        let result = try await service.fetchBirthdayContacts()
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].givenName, "Alice")
    }

    func testFetchBirthdayContacts_emptyStore_returnsEmpty() async throws {
        mockStore.stubbedContacts = []
        let result = try await service.fetchBirthdayContacts()
        XCTAssertTrue(result.isEmpty)
    }

    func testFetchBirthdayContacts_allContactsWithoutBirthday_returnsEmpty() async throws {
        mockStore.stubbedContacts = [
            makeContact(withBirthday: false, given: "A"),
            makeContact(withBirthday: false, given: "B"),
        ]
        let result = try await service.fetchBirthdayContacts()
        XCTAssertTrue(result.isEmpty)
    }

    func testFetchBirthdayContacts_storeError_throws() async {
        mockStore.stubbedEnumerateError = NSError(domain: "CNErrorDomain", code: 200)
        do {
            _ = try await service.fetchBirthdayContacts()
            XCTFail("Expected error to be thrown")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "CNErrorDomain")
            XCTAssertEqual(error.code, 200)
        }
    }
}
