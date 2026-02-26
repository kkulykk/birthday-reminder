import XCTest
import SwiftData
@testable import BirthdayReminder

// MARK: - Helpers

extension OpenAIServiceTests {
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
            "choices": [
                [
                    "message": [
                        "role": "assistant",
                        "content": text
                    ]
                ]
            ]
        ]
    }
}

// MARK: - OpenAIServiceTests

final class OpenAIServiceTests: XCTestCase {

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
        let prompt = OpenAIService.buildPrompt(for: person, customPrompt: nil)
        XCTAssertTrue(prompt.contains("Jane Doe"), "Prompt should contain full name")
    }

    func testBuildPrompt_givenNameOnly() {
        let person = makePerson(given: "Alice", family: "")
        let prompt = OpenAIService.buildPrompt(for: person, customPrompt: nil)
        XCTAssertTrue(prompt.contains("Alice"), "Prompt should contain given name")
    }

    func testBuildPrompt_withCustomPrompt() {
        let person = makePerson(given: "Dan", family: "Brown")
        let custom = "Keep it funny and short."
        let prompt = OpenAIService.buildPrompt(for: person, customPrompt: custom)
        XCTAssertTrue(prompt.contains(custom), "Custom prompt should be appended")
    }

    func testBuildPrompt_withEmptyCustomPrompt_notAppended() {
        let person = makePerson(given: "Frank", family: "Green")
        let prompt = OpenAIService.buildPrompt(for: person, customPrompt: "")
        XCTAssertTrue(prompt.hasSuffix("."), "Empty custom prompt should not be appended")
    }

    // MARK: - parseResponse Tests

    func testParseResponse_validResponse_extractsText() throws {
        let json = successResponse(text: "Happy Birthday!")
        let data = try JSONSerialization.data(withJSONObject: json)
        let result = try OpenAIService.parseResponse(data)
        XCTAssertEqual(result, "Happy Birthday!")
    }

    func testParseResponse_missingChoicesKey_throwsParsingError() throws {
        let json: [String: Any] = ["id": "chatcmpl-123"]
        let data = try JSONSerialization.data(withJSONObject: json)
        XCTAssertThrowsError(try OpenAIService.parseResponse(data)) { error in
            XCTAssertEqual(error as? OpenAIError, OpenAIError.parsingError)
        }
    }

    func testParseResponse_emptyChoicesArray_throwsParsingError() throws {
        let json: [String: Any] = ["choices": [[String: Any]]()]
        let data = try JSONSerialization.data(withJSONObject: json)
        XCTAssertThrowsError(try OpenAIService.parseResponse(data)) { error in
            XCTAssertEqual(error as? OpenAIError, OpenAIError.parsingError)
        }
    }

    func testParseResponse_malformedJSON_throwsParsingError() {
        let data = Data("not json at all".utf8)
        XCTAssertThrowsError(try OpenAIService.parseResponse(data)) { error in
            XCTAssertEqual(error as? OpenAIError, OpenAIError.parsingError)
        }
    }

    func testParseResponse_apiErrorResponse_throwsAPIError() throws {
        let json: [String: Any] = [
            "error": ["type": "invalid_request_error", "message": "Bad request"]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        XCTAssertThrowsError(try OpenAIService.parseResponse(data)) { error in
            if case .apiError(let msg) = error as? OpenAIError {
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

        let service = OpenAIService(session: mockSession)
        let person = makePerson(given: "Gina", family: "Hill")
        let result = try await service.generateCongratulation(for: person, apiKey: "test-key", customPrompt: nil)
        XCTAssertEqual(result, "Wishing you a wonderful birthday!")
    }

    func testGenerateCongratulation_http401_throwsInvalidAPIKey() async {
        let mockSession = MockURLSession()
        mockSession.setHTTPStatus(401)
        mockSession.setJSONResponse(["error": ["message": "Unauthorized"]])

        let service = OpenAIService(session: mockSession)
        let person = makePerson()
        do {
            _ = try await service.generateCongratulation(for: person, apiKey: "bad-key", customPrompt: nil)
            XCTFail("Expected invalidAPIKey error")
        } catch {
            XCTAssertEqual(error as? OpenAIError, OpenAIError.invalidAPIKey)
        }
    }

    func testGenerateCongratulation_http500_throwsAPIError() async {
        let mockSession = MockURLSession()
        mockSession.setHTTPStatus(500)
        mockSession.setJSONResponse(["error": ["message": "Internal server error"]])

        let service = OpenAIService(session: mockSession)
        let person = makePerson()
        do {
            _ = try await service.generateCongratulation(for: person, apiKey: "test-key", customPrompt: nil)
            XCTFail("Expected apiError")
        } catch {
            if case .apiError(let msg) = error as? OpenAIError {
                XCTAssertEqual(msg, "Internal server error")
            } else {
                XCTFail("Expected apiError but got \(error)")
            }
        }
    }

    func testGenerateCongratulation_networkFailure_throwsNetworkError() async {
        let mockSession = MockURLSession()
        mockSession.stubbedError = URLError(.notConnectedToInternet)

        let service = OpenAIService(session: mockSession)
        let person = makePerson()
        do {
            _ = try await service.generateCongratulation(for: person, apiKey: "test-key", customPrompt: nil)
            XCTFail("Expected networkError")
        } catch {
            if case .networkError = error as? OpenAIError {
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

        let service = OpenAIService(session: mockSession)
        let person = makePerson()
        _ = try await service.generateCongratulation(for: person, apiKey: "sk-test-12345", customPrompt: nil)

        let req = try XCTUnwrap(mockSession.capturedRequest)
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test-12345")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testGenerateCongratulation_requestBody_containsModelAndMaxTokens() async throws {
        let mockSession = MockURLSession()
        mockSession.setHTTPStatus(200)
        mockSession.setJSONResponse(successResponse(text: "Happy Birthday!"))

        let service = OpenAIService(session: mockSession)
        let person = makePerson()
        _ = try await service.generateCongratulation(for: person, apiKey: "test-key", customPrompt: nil)

        let req = try XCTUnwrap(mockSession.capturedRequest)
        let bodyData = try XCTUnwrap(req.httpBody)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])

        XCTAssertEqual(body["model"] as? String, "gpt-4o-mini")
        XCTAssertEqual(body["max_tokens"] as? Int, 256)
    }

    func testGenerateCongratulation_withCustomPrompt_appendedInBody() async throws {
        let mockSession = MockURLSession()
        mockSession.setHTTPStatus(200)
        mockSession.setJSONResponse(successResponse(text: "Happy Birthday!"))

        let service = OpenAIService(session: mockSession)
        let person = makePerson(given: "Hank", family: "Ford")
        let customPrompt = "Make it rhyme."
        _ = try await service.generateCongratulation(for: person, apiKey: "test-key", customPrompt: customPrompt)

        let req = try XCTUnwrap(mockSession.capturedRequest)
        let bodyData = try XCTUnwrap(req.httpBody)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        let userContent = try XCTUnwrap(messages.last?["content"] as? String)

        XCTAssertTrue(userContent.contains("Make it rhyme."), "Custom prompt should appear in message body")
    }

    func testGenerateCongratulation_withEmptyCustomPrompt_notAppended() async throws {
        let mockSession = MockURLSession()
        mockSession.setHTTPStatus(200)
        mockSession.setJSONResponse(successResponse(text: "Happy Birthday!"))

        let service = OpenAIService(session: mockSession)
        let person = makePerson(given: "Iris", family: "Lang")
        _ = try await service.generateCongratulation(for: person, apiKey: "test-key", customPrompt: "")

        let req = try XCTUnwrap(mockSession.capturedRequest)
        let bodyData = try XCTUnwrap(req.httpBody)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        let userContent = try XCTUnwrap(messages.last?["content"] as? String)

        XCTAssertTrue(userContent.hasSuffix("."), "No extra text should be appended for empty custom prompt")
    }

    // MARK: - validateAPIKey Tests

    func testValidateAPIKey_success_doesNotThrow() async throws {
        let mockSession = MockURLSession()
        mockSession.setHTTPStatus(200)
        mockSession.setJSONResponse(["object": "list"])

        let service = OpenAIService(session: mockSession)
        try await service.validateAPIKey("valid-key")  // should not throw
    }

    func testValidateAPIKey_http401_throwsInvalidAPIKey() async {
        let mockSession = MockURLSession()
        mockSession.setHTTPStatus(401)

        let service = OpenAIService(session: mockSession)
        do {
            try await service.validateAPIKey("bad-key")
            XCTFail("Expected invalidAPIKey error")
        } catch {
            XCTAssertEqual(error as? OpenAIError, OpenAIError.invalidAPIKey)
        }
    }

    func testValidateAPIKey_http500_doesNotThrow() async throws {
        // Only 401 maps to invalidAPIKey; other status codes are not validation failures
        let mockSession = MockURLSession()
        mockSession.setHTTPStatus(500)
        mockSession.setJSONResponse([:])

        let service = OpenAIService(session: mockSession)
        try await service.validateAPIKey("test-key")  // should not throw
    }

    func testValidateAPIKey_networkError_throwsNetworkError() async {
        let mockSession = MockURLSession()
        mockSession.stubbedError = URLError(.notConnectedToInternet)

        let service = OpenAIService(session: mockSession)
        do {
            try await service.validateAPIKey("test-key")
            XCTFail("Expected networkError")
        } catch {
            if case .networkError = error as? OpenAIError {
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

        let service = OpenAIService(session: mockSession)
        try await service.validateAPIKey("sk-openai-test-key")

        let req = try XCTUnwrap(mockSession.capturedRequest)
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer sk-openai-test-key")
    }

    func testValidateAPIKey_requestMethod_isGet() async throws {
        let mockSession = MockURLSession()
        mockSession.setHTTPStatus(200)
        mockSession.setJSONResponse([:])

        let service = OpenAIService(session: mockSession)
        try await service.validateAPIKey("test-key")

        let req = try XCTUnwrap(mockSession.capturedRequest)
        XCTAssertEqual(req.httpMethod, "GET")
    }
}

// MARK: - OpenAIError Equatable

extension OpenAIError: Equatable {
    public static func == (lhs: OpenAIError, rhs: OpenAIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidAPIKey, .invalidAPIKey): return true
        case (.parsingError, .parsingError): return true
        case (.apiError(let a), .apiError(let b)): return a == b
        case (.networkError, .networkError): return true
        default: return false
        }
    }
}
