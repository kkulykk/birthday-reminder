import Foundation

// MARK: - Errors

enum AnthropicError: Error, LocalizedError {
    case invalidAPIKey
    case apiError(String)
    case parsingError
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key. Please check your Anthropic API key in Settings."
        case .apiError(let message):
            return "API error: \(message)"
        case .parsingError:
            return "Failed to parse the response from the API."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - URLSession Protocol (for testability)

protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

// MARK: - AnthropicService

struct AnthropicService {
    private let session: URLSessionProtocol

    init(session: URLSessionProtocol = URLSession.shared) {
        self.session = session
    }

    // MARK: - Static Helpers

    static func buildPrompt(for person: Person, customPrompt: String?) -> String {
        let name = person.fullName.isEmpty ? person.givenName : person.fullName
        var message = "Write a warm 2-3 sentence birthday congratulation for \(name)"

        if let turningAge = person.turningAge {
            message += ", who is turning \(turningAge) today"
        }

        message += "."

        if let custom = customPrompt, !custom.isEmpty {
            message += " \(custom)"
        }

        return message
    }

    static func parseResponse(_ data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AnthropicError.parsingError
        }

        // Check for API-level error response
        if let errorObj = json["error"] as? [String: Any],
           let message = errorObj["message"] as? String {
            throw AnthropicError.apiError(message)
        }

        guard let content = json["content"] as? [[String: Any]],
              !content.isEmpty,
              let text = content[0]["text"] as? String else {
            throw AnthropicError.parsingError
        }

        return text
    }

    // MARK: - Key Validation

    func validateAPIKey(_ key: String) async throws {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw AnthropicError.apiError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1,
            "messages": [["role": "user", "content": "Hi"]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let response: URLResponse
        do {
            (_, response) = try await session.data(for: request)
        } catch {
            throw AnthropicError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            throw AnthropicError.invalidAPIKey
        }
    }

    // MARK: - API Call

    func generateCongratulation(for person: Person, apiKey: String, customPrompt: String?) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw AnthropicError.apiError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 256,
            "system": "You are a warm, friendly birthday message writer. Write short, genuine, and personal messages.",
            "messages": [
                ["role": "user", "content": Self.buildPrompt(for: person, customPrompt: customPrompt)]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AnthropicError.networkError(error)
        }

        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200...299:
                break
            case 401:
                throw AnthropicError.invalidAPIKey
            default:
                let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                    .flatMap { $0["error"] as? [String: Any] }
                    .flatMap { $0["message"] as? String }
                    ?? "HTTP \(http.statusCode)"
                throw AnthropicError.apiError(message)
            }
        }

        return try Self.parseResponse(data)
    }
}
