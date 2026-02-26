import XCTest
import SwiftData
import UserNotifications
@testable import BirthdayReminder

// MARK: - MockNotificationCenter

final class MockNotificationCenter: NotificationCenterProtocol {
    var stubbedIsAuthorized = false
    var stubbedAuthorizationResult = true
    var stubbedAuthorizationError: Error? = nil
    var stubbedAddError: Error? = nil

    private(set) var removeAllPendingCalled = false
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var removedPendingIdentifiers: [String] = []
    private(set) var removedDeliveredIdentifiers: [String] = []

    func isAlreadyAuthorized() async -> Bool { stubbedIsAuthorized }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        if let error = stubbedAuthorizationError { throw error }
        return stubbedAuthorizationResult
    }

    func removeAllPendingNotificationRequests() {
        removeAllPendingCalled = true
    }

    func add(_ request: UNNotificationRequest) async throws {
        if let error = stubbedAddError { throw error }
        addedRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedPendingIdentifiers.append(contentsOf: identifiers)
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        removedDeliveredIdentifiers.append(contentsOf: identifiers)
    }
}

// MARK: - NotificationServiceTests

final class NotificationServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var mockCenter: MockNotificationCenter!
    private var service: NotificationService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([Person.self, WishlistItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        mockCenter = MockNotificationCenter()
        service = NotificationService(center: mockCenter)
    }

    override func tearDownWithError() throws {
        service = nil
        mockCenter = nil
        context = nil
        container = nil
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func makePerson(
        given: String = "Alice",
        family: String = "Smith",
        month: Int = 6,
        day: Int = 15,
        year: Int? = nil,
        congratulatedYear: Int? = nil
    ) -> Person {
        let p = Person()
        p.givenName = given
        p.familyName = family
        p.birthdayMonth = month
        p.birthdayDay = day
        p.birthdayYear = year
        p.congratulatedYear = congratulatedYear
        context.insert(p)
        return p
    }

    private var todayMonth: Int { Calendar.current.component(.month, from: Date()) }
    private var todayDay: Int { Calendar.current.component(.day, from: Date()) }
    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }

    // MARK: - requestPermission

    func testRequestPermission_alreadyAuthorized_returnsTrueWithoutRequesting() async {
        mockCenter.stubbedIsAuthorized = true
        let result = await service.requestPermission()
        XCTAssertTrue(result)
    }

    func testRequestPermission_notAuthorized_requestGranted_returnsTrue() async {
        mockCenter.stubbedIsAuthorized = false
        mockCenter.stubbedAuthorizationResult = true
        let result = await service.requestPermission()
        XCTAssertTrue(result)
    }

    func testRequestPermission_notAuthorized_requestDenied_returnsFalse() async {
        mockCenter.stubbedIsAuthorized = false
        mockCenter.stubbedAuthorizationResult = false
        let result = await service.requestPermission()
        XCTAssertFalse(result)
    }

    func testRequestPermission_notAuthorized_requestThrows_returnsFalse() async {
        mockCenter.stubbedIsAuthorized = false
        mockCenter.stubbedAuthorizationError = URLError(.unknown)
        let result = await service.requestPermission()
        XCTAssertFalse(result)
    }

    // MARK: - rescheduleAll

    func testRescheduleAll_alwaysCallsRemoveAllPending() async {
        await service.rescheduleAll(people: [])
        XCTAssertTrue(mockCenter.removeAllPendingCalled)
    }

    func testRescheduleAll_emptyList_noNotificationsAdded() async {
        await service.rescheduleAll(people: [])
        XCTAssertTrue(mockCenter.addedRequests.isEmpty)
    }

    func testRescheduleAll_futureBirthday_usesCalendarTrigger() async {
        // Use a month that is not today
        let month = (todayMonth % 12) + 1
        let person = makePerson(month: month, day: 15)
        await service.rescheduleAll(people: [person])
        XCTAssertEqual(mockCenter.addedRequests.count, 1)
        let trigger = mockCenter.addedRequests[0].trigger
        XCTAssertTrue(trigger is UNCalendarNotificationTrigger, "Future birthday should use calendar trigger")
        let calTrigger = trigger as? UNCalendarNotificationTrigger
        XCTAssertEqual(calTrigger?.dateComponents.month, month)
        XCTAssertEqual(calTrigger?.dateComponents.day, 15)
        XCTAssertTrue(calTrigger?.repeats ?? false)
    }

    func testRescheduleAll_birthdayToday_usesTimeIntervalTrigger() async {
        let person = makePerson(month: todayMonth, day: todayDay)
        await service.rescheduleAll(people: [person])
        XCTAssertEqual(mockCenter.addedRequests.count, 1)
        let trigger = mockCenter.addedRequests[0].trigger
        XCTAssertTrue(trigger is UNTimeIntervalNotificationTrigger, "Today's birthday should use time interval trigger")
        let timeTrigger = trigger as? UNTimeIntervalNotificationTrigger
        XCTAssertEqual(timeTrigger?.timeInterval, 2)
        XCTAssertFalse(timeTrigger?.repeats ?? true)
    }

    func testRescheduleAll_congratulatedPerson_isFiltered() async {
        let person = makePerson(congratulatedYear: currentYear)
        await service.rescheduleAll(people: [person])
        XCTAssertTrue(mockCenter.addedRequests.isEmpty)
    }

    func testRescheduleAll_personWithNoBirthdayMonth_isFiltered() async {
        let p = Person()
        p.givenName = "No"
        p.familyName = "Birthday"
        p.birthdayMonth = nil
        p.birthdayDay = nil
        context.insert(p)
        await service.rescheduleAll(people: [p])
        XCTAssertTrue(mockCenter.addedRequests.isEmpty)
    }

    func testRescheduleAll_personWithMonthButNilDay_isSkipped() async {
        // Passes the filter (birthdayMonth != nil) but fails the guard (birthdayDay is nil)
        let p = Person()
        p.givenName = "Bad"
        p.familyName = "Data"
        p.birthdayMonth = 5
        p.birthdayDay = nil
        context.insert(p)
        await service.rescheduleAll(people: [p])
        XCTAssertTrue(mockCenter.addedRequests.isEmpty)
    }

    func testRescheduleAll_notificationIdFormat() async {
        let person = makePerson(month: (todayMonth % 12) + 1, day: 10)
        await service.rescheduleAll(people: [person])
        XCTAssertEqual(mockCenter.addedRequests.count, 1)
        XCTAssertEqual(mockCenter.addedRequests[0].identifier, "birthday-\(person.id.uuidString)")
    }

    func testRescheduleAll_notificationContent_includesPersonName() async {
        let person = makePerson(given: "Jane", family: "Doe", month: (todayMonth % 12) + 1, day: 10)
        await service.rescheduleAll(people: [person])
        XCTAssertEqual(mockCenter.addedRequests.count, 1)
        XCTAssertTrue(mockCenter.addedRequests[0].content.title.contains("Jane Doe"))
    }

    func testRescheduleAll_notificationContent_withKnownAge_showsTurningAge() async {
        let person = makePerson(
            month: todayMonth,
            day: todayDay,
            year: currentYear - 30
        )
        await service.rescheduleAll(people: [person])
        XCTAssertEqual(mockCenter.addedRequests.count, 1)
        XCTAssertTrue(mockCenter.addedRequests[0].content.body.contains("Turning 30"))
    }

    func testRescheduleAll_notificationContent_withoutAge_showsFallback() async {
        // No birth year → turningAge is nil → fallback body
        let person = makePerson(month: (todayMonth % 12) + 1, day: 10, year: nil)
        await service.rescheduleAll(people: [person])
        XCTAssertEqual(mockCenter.addedRequests.count, 1)
        XCTAssertEqual(mockCenter.addedRequests[0].content.body, "Don't forget to reach out!")
    }

    func testRescheduleAll_notificationContent_personIdInUserInfo() async {
        let person = makePerson(month: (todayMonth % 12) + 1, day: 10)
        await service.rescheduleAll(people: [person])
        XCTAssertEqual(mockCenter.addedRequests.count, 1)
        let userInfo = mockCenter.addedRequests[0].content.userInfo
        XCTAssertEqual(userInfo["personID"] as? String, person.id.uuidString)
    }

    func testRescheduleAll_limitsTo64Notifications() async {
        // Create 65 people with different future birthdays
        var people: [Person] = []
        for i in 1...65 {
            let month = ((i - 1) % 11) + 1  // months 1-11, avoiding today
            let day = (i % 28) + 1
            // Skip month+day combos that match today
            let effectiveMonth = (month == todayMonth && day == todayDay) ? (month % 11) + 1 : month
            people.append(makePerson(given: "Person\(i)", month: effectiveMonth, day: day))
        }
        await service.rescheduleAll(people: people)
        XCTAssertLessThanOrEqual(mockCenter.addedRequests.count, 64)
    }

    func testRescheduleAll_addError_isSilentlyIgnored() async {
        mockCenter.stubbedAddError = URLError(.unknown)
        let person = makePerson(month: (todayMonth % 12) + 1, day: 10)
        // Should not throw — uses try? internally
        await service.rescheduleAll(people: [person])
        // No crash = success; add was attempted (error swallowed)
        XCTAssertTrue(mockCenter.addedRequests.isEmpty)
    }

    // MARK: - cancelNotification

    func testCancelNotification_removesPendingWithCorrectId() {
        let id = UUID()
        service.cancelNotification(for: id)
        XCTAssertEqual(mockCenter.removedPendingIdentifiers, ["birthday-\(id.uuidString)"])
    }

    func testCancelNotification_removesDeliveredWithCorrectId() {
        let id = UUID()
        service.cancelNotification(for: id)
        XCTAssertEqual(mockCenter.removedDeliveredIdentifiers, ["birthday-\(id.uuidString)"])
    }

    func testCancelNotification_differentIds_areIndependent() {
        let id1 = UUID()
        let id2 = UUID()
        service.cancelNotification(for: id1)
        service.cancelNotification(for: id2)
        XCTAssertEqual(mockCenter.removedPendingIdentifiers.count, 2)
        XCTAssertEqual(mockCenter.removedPendingIdentifiers[0], "birthday-\(id1.uuidString)")
        XCTAssertEqual(mockCenter.removedPendingIdentifiers[1], "birthday-\(id2.uuidString)")
    }
}
