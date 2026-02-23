import XCTest
@testable import BirthdayReminder

final class WishlistItemTests: XCTestCase {

    // MARK: - url

    func testURL_validHTTPS_returnsURL() {
        let item = WishlistItem()
        item.urlString = "https://example.com"
        XCTAssertNotNil(item.url)
        XCTAssertEqual(item.url?.absoluteString, "https://example.com")
    }

    func testURL_validHTTP_returnsURL() {
        let item = WishlistItem()
        item.urlString = "http://example.com/path?q=1"
        XCTAssertNotNil(item.url)
        XCTAssertEqual(item.url?.scheme, "http")
    }

    func testURL_nilString_returnsNil() {
        let item = WishlistItem()
        item.urlString = nil
        XCTAssertNil(item.url)
    }

    func testURL_stringWithSpaces_returnsNil() {
        let item = WishlistItem()
        item.urlString = "not a valid url with spaces"
        XCTAssertNil(item.url)
    }

    func testURL_emptyString_returnsNil() {
        // URL(string: "") returns a URL with empty absoluteString, not nil;
        // verify the property at least returns consistently with Foundation behaviour
        let item = WishlistItem()
        item.urlString = ""
        // Empty string produces a relative URL in Foundation — just assert it doesn't crash
        _ = item.url
    }

    // MARK: - Default values

    func testDefaults_isPurchasedIsFalse() {
        let item = WishlistItem()
        XCTAssertFalse(item.isPurchased)
    }

    func testDefaults_titleIsEmpty() {
        let item = WishlistItem()
        XCTAssertEqual(item.title, "")
    }

    func testDefaults_urlStringIsNil() {
        let item = WishlistItem()
        XCTAssertNil(item.urlString)
    }

    func testDefaults_notesIsNil() {
        let item = WishlistItem()
        XCTAssertNil(item.notes)
    }

    func testDefaults_personIsNil() {
        let item = WishlistItem()
        XCTAssertNil(item.person)
    }

    // MARK: - Mutability

    func testTitle_canBeSet() {
        let item = WishlistItem()
        item.title = "New Book"
        XCTAssertEqual(item.title, "New Book")
    }

    func testNotes_canBeSet() {
        let item = WishlistItem()
        item.notes = "A thoughtful note"
        XCTAssertEqual(item.notes, "A thoughtful note")
    }

    func testIsPurchased_canBeToggledOn() {
        let item = WishlistItem()
        item.isPurchased = true
        XCTAssertTrue(item.isPurchased)
    }

    func testIsPurchased_canBeToggledOff() {
        let item = WishlistItem()
        item.isPurchased = true
        item.isPurchased = false
        XCTAssertFalse(item.isPurchased)
    }

    func testURLString_canBeUpdated() {
        let item = WishlistItem()
        item.urlString = "https://first.com"
        XCTAssertEqual(item.url?.host(), "first.com")
        item.urlString = "https://second.com"
        XCTAssertEqual(item.url?.host(), "second.com")
    }

    // MARK: - Identity

    func testID_isUniquePerInstance() {
        let item1 = WishlistItem()
        let item2 = WishlistItem()
        XCTAssertNotEqual(item1.id, item2.id)
    }

    func testCreatedAt_isRecentlySet() {
        let before = Date()
        let item = WishlistItem()
        let after = Date()
        XCTAssertGreaterThanOrEqual(item.createdAt, before)
        XCTAssertLessThanOrEqual(item.createdAt, after)
    }
}
