import XCTest
import SwiftData
@testable import BirthdayReminder

// MARK: - MockURLSession

final class MockURLSession: URLSessionProtocol {
    var stubbedData: Data = Data()
    var stubbedResponse: URLResponse = HTTPURLResponse(
        url: URL(string: "https://api.anthropic.com/v1/messages")!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
    )!
    var stubbedError: Error? = nil
    var capturedRequest: URLRequest? = nil

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        capturedRequest = request
        if let error = stubbedError { throw error }
        return (stubbedData, stubbedResponse)
    }

    func setHTTPStatus(_ statusCode: Int) {
        stubbedResponse = HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/v1/messages")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    func setJSONResponse(_ dict: [String: Any]) {
        stubbedData = (try? JSONSerialization.data(withJSONObject: dict)) ?? Data()
    }
}

// MARK: - Helpers

extension AnthropicServiceTests {
    private func makePerson(given: String = "Jane", family: String = "Doe", year: Int? = nil) -> Person {
        let p = Person()
        p.givenName = given
        p.familyName = family
        p.birthdayMonth = 6
        p.birthdayDay = 15
        p.birthdayYear = year
        context.insert(p)
        return p
    }

    private func successResponse(text: String) -> [String: Any] {
        [
            "content": [
                ["type": "text", "text": text]
            ],
            "model": "claude-haiku-4-5-20251001",
            "role": "assistant"
        ]
    }
}

// MARK: - AnthropicServiceTests

final class AnthropicServiceTests: XCTestCase {

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

    // MARK: - buildPrompt Tests

    func testBuildPrompt_givenAndFamilyName() {
        let person = makePerson(given: "Jane", family: "Doe")
        let prompt = AnthropicService.buildPrompt(for: person, customPrompt: nil)
        XCTAssertTrue(prompt.contains("Jane Doe"), "Prompt should contain full name")
    }

    func testBuildPrompt_givenNameOnly() {
        let person = makePerson(given: "Alice", family: "")
        let prompt = AnthropicService.buildPrompt(for: person, customPrompt: nil)
        XCTAssertTrue(prompt.contains("Alice"), "Prompt should contain given name")
    }

    func testBuildPrompt_withAge() {
        // Year such that turningAge is computable — use current year minus some age
        let currentYear = Calendar.current.component(.year, from: Date())
        let person = makePerson(given: "Bob", family: "Smith", year: currentYear - 30)
        // Force birthday to be today or upcoming so turningAge is defined
        person.birthdayMonth = Calendar.current.component(.month, from: Date())
        person.birthdayDay = Calendar.current.component(.day, from: Date())
        let prompt = AnthropicService.buildPrompt(for: person, customPrompt: nil)
        XCTAssertTrue(prompt.contains("turning"), "Prompt should contain 'turning' when age is known")
        XCTAssertTrue(prompt.contains("30"), "Prompt should contain the age")
    }

    func testBuildPrompt_withoutAge_noYear() {
        let person = makePerson(given: "Carol", family: "White", year: nil)
        let prompt = AnthropicService.buildPrompt(for: person, customPrompt: nil)
        XCTAssertFalse(prompt.contains("turning"), "Prompt should not mention age when year is unknown")
    }

    func testBuildPrompt_withCustomPrompt() {
        let person = makePerson(given: "Dan", family: "Brown")
        let custom = "Keep it funny and short."
        let prompt = AnthropicService.buildPrompt(for: person, customPrompt: custom)
        XCTAssertTrue(prompt.contains(custom), "Custom prompt should be appended")
    }

    func testBuildPrompt_withoutCustomPrompt() {
        let person = makePerson(given: "Eve", family: "Black")
        let prompt = AnthropicService.buildPrompt(for: person, customPrompt: nil)
        XCTAssertTrue(prompt.hasSuffix("."), "Prompt without custom text should end with period")
    }

    func testBuildPrompt_withEmptyCustomPrompt_notAppended() {
        let person = makePerson(given: "Frank", family: "Green")
        let prompt = AnthropicService.buildPrompt(for: person, customPrompt: "")
        XCTAssertTrue(prompt.hasSuffix("."), "Empty custom prompt should not be appended")
    }

    // MARK: - parseResponse Tests

    func testParseResponse_validResponse_extractsText() throws {
        let json = successResponse(text: "Happy Birthday!")
        let data = try JSONSerialization.data(withJSONObject: json)
        let result = try AnthropicService.parseResponse(data)
        XCTAssertEqual(result, "Happy Birthday!")
    }

    func testParseResponse_missingContentKey_throwsParsingError() throws {
        let json: [String: Any] = ["role": "assistant"]
        let data = try JSONSerialization.data(withJSONObject: json)
        XCTAssertThrowsError(try AnthropicService.parseResponse(data)) { error in
            XCTAssertEqual(error as? AnthropicError, AnthropicError.parsingError)
        }
    }

    func testParseResponse_emptyContentArray_throwsParsingError() throws {
        let json: [String: Any] = ["content": [[String: Any]]()]
        let data = try JSONSerialization.data(withJSONObject: json)
        XCTAssertThrowsError(try AnthropicService.parseResponse(data)) { error in
            XCTAssertEqual(error as? AnthropicError, AnthropicError.parsingError)
        }
    }

    func testParseResponse_malformedJSON_throwsParsingError() {
        let data = Data("not json at all".utf8)
        XCTAssertThrowsError(try AnthropicService.parseResponse(data)) { error in
            XCTAssertEqual(error as? AnthropicError, AnthropicError.parsingError)
        }
    }

    func testParseResponse_apiErrorResponse_throwsAPIError() throws {
        let json: [String: Any] = [
            "error": ["type": "invalid_request_error", "message": "Bad request"]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        XCTAssertThrowsError(try AnthropicService.parseResponse(data)) { error in
            if case .apiError(let msg) = error as? AnthropicError {
                XCTAssertEqual(msg, "Bad request")
            } else {
                XCTFail("Expected apiError but got \(error)")
            }
        }
    }

    // MARK: - generateCongratulation Tests

    func testGenerateCongratulation_success_returnsText() async throws {
        let mockSession = MockURLSession()
        mockSession.setHTTPStatus(200)
        mockSession.setJSONResponse(successResponse(text: "Wishing you a wonderful birthday!"))

        let service = AnthropicService(session: mockSession)
        let person = makePerson(given: "Gina", family: "Hill")
        let result = try await service.generateCongratulation(for: person, apiKey: "test-key", customPrompt: nil)
        XCTAssertEqual(result, "Wishing you a wonderful birthday!")
    }

    func testGenerateCongratulation_http401_throwsInvalidAPIKey() async {
        let mockSession = MockURLSession()
        mockSession.setHTTPStatus(401)
        mockSession.setJSONResponse(["error": ["message": "Unauthorized"]])

        let service = AnthropicService(session: mockSession)
        let person = makePerson()
        do {
            _ = try await service.generateCongratulation(for: person, apiKey: "bad-key", customPrompt: nil)
            XCTFail("Expected invalidAPIKey error")
        } catch {
            XCTAssertEqual(error as? AnthropicError, AnthropicError.invalidAPIKey)
        }
    }

    func testGenerateCongratulation_http500_throwsAPIError() async {
        let mockSession = MockURLSession()
        mockSession.setHTTPStatus(500)
        mockSession.setJSONResponse(["error": ["message": "Internal server error"]])

        let service = AnthropicService(session: mockSession)
        let person = makePerson()
        do {
            _ = try await service.generateCongratulation(for: person, apiKey: "test-key", customPrompt: nil)
            XCTFail("Expected apiError")
        } catch {
            if case .apiError(let msg) = error as? AnthropicError {
                XCTAssertEqual(msg, "Internal server error")
            } else {
                XCTFail("Expected apiError but got \(error)")
            }
        }
    }

    func testGenerateCongratulation_networkFailure_throwsNetworkError() async {
        let mockSession = MockURLSession()
        mockSession.stubbedError = URLError(.notConnectedToInternet)

        let service = AnthropicService(session: mockSession)
        let person = makePerson()
        do {
            _ = try await service.generateCongratulation(for: person, apiKey: "test-key", customPrompt: nil)
            XCTFail("Expected networkError")
        } catch {
            if case .networkError = error as? AnthropicError {
                // expected
            } else {
                XCTFail("Expected networkError but got \(error)")
            }
        }
    }

    func testGenerateCongratulation_requestHeaders() async throws {
        let mockSession = MockURLSession()
        mockSession.setHTTPStatus(200)
        mockSession.setJSONResponse(successResponse(text: "Happy Birthday!"))

        let service = AnthropicService(session: mockSession)
        let person = makePerson()
        _ = try await service.generateCongratulation(for: person, apiKey: "sk-test-12345", customPrompt: nil)

        let req = try XCTUnwrap(mockSession.capturedRequest)
        XCTAssertEqual(req.value(forHTTPHeaderField: "x-api-key"), "sk-test-12345")
        XCTAssertEqual(req.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertEqual(req.value(forHTTPHeaderField: "content-type"), "application/json")
    }

    func testGenerateCongratulation_requestBody_containsModelAndMaxTokens() async throws {
        let mockSession = MockURLSession()
        mockSession.setHTTPStatus(200)
        mockSession.setJSONResponse(successResponse(text: "Happy Birthday!"))

        let service = AnthropicService(session: mockSession)
        let person = makePerson()
        _ = try await service.generateCongratulation(for: person, apiKey: "test-key", customPrompt: nil)

        let req = try XCTUnwrap(mockSession.capturedRequest)
        let bodyData = try XCTUnwrap(req.httpBody)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])

        XCTAssertEqual(body["model"] as? String, "claude-haiku-4-5-20251001")
        XCTAssertEqual(body["max_tokens"] as? Int, 256)
    }

    func testGenerateCongratulation_withCustomPrompt_appendedInBody() async throws {
        let mockSession = MockURLSession()
        mockSession.setHTTPStatus(200)
        mockSession.setJSONResponse(successResponse(text: "Happy Birthday!"))

        let service = AnthropicService(session: mockSession)
        let person = makePerson(given: "Hank", family: "Ford")
        let customPrompt = "Make it rhyme."
        _ = try await service.generateCongratulation(for: person, apiKey: "test-key", customPrompt: customPrompt)

        let req = try XCTUnwrap(mockSession.capturedRequest)
        let bodyData = try XCTUnwrap(req.httpBody)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        let userContent = try XCTUnwrap(messages.first?["content"] as? String)

        XCTAssertTrue(userContent.contains("Make it rhyme."), "Custom prompt should appear in message body")
    }

    func testGenerateCongratulation_withEmptyCustomPrompt_notAppended() async throws {
        let mockSession = MockURLSession()
        mockSession.setHTTPStatus(200)
        mockSession.setJSONResponse(successResponse(text: "Happy Birthday!"))

        let service = AnthropicService(session: mockSession)
        let person = makePerson(given: "Iris", family: "Lang")
        _ = try await service.generateCongratulation(for: person, apiKey: "test-key", customPrompt: "")

        let req = try XCTUnwrap(mockSession.capturedRequest)
        let bodyData = try XCTUnwrap(req.httpBody)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        let userContent = try XCTUnwrap(messages.first?["content"] as? String)

        // With nil passed for empty string, there should be no extra content after the final period
        XCTAssertTrue(userContent.hasSuffix("."), "No extra text should be appended for empty custom prompt")
    }

    // MARK: - validateAPIKey Tests

    func testValidateAPIKey_success_doesNotThrow() async throws {
        let mockSession = MockURLSession()
        mockSession.setHTTPStatus(200)
        mockSession.setJSONResponse(["id": "msg_123"])

        let service = AnthropicService(session: mockSession)
        try await service.validateAPIKey("valid-key")  // should not throw
    }

    func testValidateAPIKey_http401_throwsInvalidAPIKey() async {
        let mockSession = MockURLSession()
        mockSession.setHTTPStatus(401)

        let service = AnthropicService(session: mockSession)
        do {
            try await service.validateAPIKey("bad-key")
            XCTFail("Expected invalidAPIKey error")
        } catch {
            XCTAssertEqual(error as? AnthropicError, AnthropicError.invalidAPIKey)
        }
    }

    func testValidateAPIKey_http500_doesNotThrow() async throws {
        // Only 401 maps to invalidAPIKey; other errors are not validation failures
        let mockSession = MockURLSession()
        mockSession.setHTTPStatus(500)
        mockSession.setJSONResponse([:])

        let service = AnthropicService(session: mockSession)
        try await service.validateAPIKey("test-key")  // should not throw
    }

    func testValidateAPIKey_networkError_throwsNetworkError() async {
        let mockSession = MockURLSession()
        mockSession.stubbedError = URLError(.notConnectedToInternet)

        let service = AnthropicService(session: mockSession)
        do {
            try await service.validateAPIKey("test-key")
            XCTFail("Expected networkError")
        } catch {
            if case .networkError = error as? AnthropicError {
                // expected
            } else {
                XCTFail("Expected networkError but got \(error)")
            }
        }
    }

    func testValidateAPIKey_requestHeaders_correct() async throws {
        let mockSession = MockURLSession()
        mockSession.setHTTPStatus(200)
        mockSession.setJSONResponse([:])

        let service = AnthropicService(session: mockSession)
        try await service.validateAPIKey("sk-ant-test-key")

        let req = try XCTUnwrap(mockSession.capturedRequest)
        XCTAssertEqual(req.value(forHTTPHeaderField: "x-api-key"), "sk-ant-test-key")
        XCTAssertEqual(req.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertEqual(req.value(forHTTPHeaderField: "content-type"), "application/json")
    }

    func testValidateAPIKey_requestMethod_isPost() async throws {
        let mockSession = MockURLSession()
        mockSession.setHTTPStatus(200)
        mockSession.setJSONResponse([:])

        let service = AnthropicService(session: mockSession)
        try await service.validateAPIKey("test-key")

        let req = try XCTUnwrap(mockSession.capturedRequest)
        XCTAssertEqual(req.httpMethod, "POST")
    }
}

// MARK: - AnthropicError Equatable

extension AnthropicError: Equatable {
    public static func == (lhs: AnthropicError, rhs: AnthropicError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidAPIKey, .invalidAPIKey): return true
        case (.parsingError, .parsingError): return true
        case (.apiError(let a), .apiError(let b)): return a == b
        case (.networkError, .networkError): return true
        default: return false
        }
    }
}
