import XCTest
@testable import BirthdayReminder

// Tests for SettingsViewLogic — the pure helpers extracted for testability (issue #13).

final class SettingsViewLogicTests: XCTestCase {

    // MARK: - shortDateString

    func testShortDateString_march8() {
        let result = SettingsViewLogic.shortDateString(month: 3, day: 8)
        XCTAssertEqual(result, "Mar 8")
    }

    func testShortDateString_january1() {
        let result = SettingsViewLogic.shortDateString(month: 1, day: 1)
        XCTAssertEqual(result, "Jan 1")
    }

    func testShortDateString_december31() {
        let result = SettingsViewLogic.shortDateString(month: 12, day: 31)
        XCTAssertEqual(result, "Dec 31")
    }

    func testShortDateString_june15() {
        let result = SettingsViewLogic.shortDateString(month: 6, day: 15)
        XCTAssertEqual(result, "Jun 15")
    }

    func testShortDateString_invalidMonth_fallsBackToNumeric() {
        // Month 13 is invalid; Calendar returns nil so we fall back to "13/5"
        let result = SettingsViewLogic.shortDateString(month: 13, day: 5)
        XCTAssertEqual(result, "13/5")
    }

    // MARK: - shortValidationError: AnthropicError

    func testShortValidationError_anthropicInvalidAPIKey() {
        let result = SettingsViewLogic.shortValidationError(AnthropicError.invalidAPIKey)
        XCTAssertEqual(result, "Invalid API key")
    }

    func testShortValidationError_anthropicNetworkError() {
        let underlying = URLError(.notConnectedToInternet)
        let result = SettingsViewLogic.shortValidationError(AnthropicError.networkError(underlying))
        XCTAssertEqual(result, "Network error — check your connection")
    }

    func testShortValidationError_anthropicAPIError() {
        let result = SettingsViewLogic.shortValidationError(AnthropicError.apiError("Rate limit exceeded"))
        XCTAssertEqual(result, "Rate limit exceeded")
    }

    func testShortValidationError_anthropicParsingError() {
        let result = SettingsViewLogic.shortValidationError(AnthropicError.parsingError)
        XCTAssertEqual(result, "Unexpected response")
    }

    // MARK: - shortValidationError: OpenAIError

    func testShortValidationError_openAIInvalidAPIKey() {
        let result = SettingsViewLogic.shortValidationError(OpenAIError.invalidAPIKey)
        XCTAssertEqual(result, "Invalid API key")
    }

    func testShortValidationError_openAINetworkError() {
        let underlying = URLError(.notConnectedToInternet)
        let result = SettingsViewLogic.shortValidationError(OpenAIError.networkError(underlying))
        XCTAssertEqual(result, "Network error — check your connection")
    }

    func testShortValidationError_openAIAPIError() {
        let result = SettingsViewLogic.shortValidationError(OpenAIError.apiError("Quota exceeded"))
        XCTAssertEqual(result, "Quota exceeded")
    }

    func testShortValidationError_openAIParsingError() {
        let result = SettingsViewLogic.shortValidationError(OpenAIError.parsingError)
        XCTAssertEqual(result, "Unexpected response")
    }

    // MARK: - shortValidationError: unknown error

    func testShortValidationError_unknownError_returnsLocalizedDescription() {
        let error = NSError(domain: "TestDomain", code: 42, userInfo: [NSLocalizedDescriptionKey: "Something went wrong"])
        let result = SettingsViewLogic.shortValidationError(error)
        XCTAssertEqual(result, "Something went wrong")
    }
}
