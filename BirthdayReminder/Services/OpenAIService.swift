import Foundation

// MARK: - Errors

enum OpenAIError: Error, LocalizedError {
    case invalidAPIKey
    case apiError(String)
    case parsingError
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key. Please check your OpenAI API key in Settings."
        case .apiError(let message):
            return "API error: \(message)"
        case .parsingError:
            return "Failed to parse the response from the API."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - OpenAIService

struct OpenAIService {
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
            throw OpenAIError.parsingError
        }

        // Check for API-level error response
        if let errorObj = json["error"] as? [String: Any],
           let message = errorObj["message"] as? String {
            throw OpenAIError.apiError(message)
        }

        guard let choices = json["choices"] as? [[String: Any]],
              !choices.isEmpty,
              let message = choices[0]["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.parsingError
        }

        return content
    }

    // MARK: - Key Validation

    func validateAPIKey(_ key: String) async throws {
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            throw OpenAIError.apiError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let response: URLResponse
        do {
            let result = try await session.data(for: request)
            response = result.1
        } catch {
            throw OpenAIError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            throw OpenAIError.invalidAPIKey
        }
    }

    // MARK: - API Call

    func generateCongratulation(for person: Person, apiKey: String, customPrompt: String?) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw OpenAIError.apiError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "max_tokens": 256,
            "messages": [
                [
                    "role": "system",
                    "content": "You are a warm, friendly birthday message writer. Write short, genuine, and personal messages."
                ],
                [
                    "role": "user",
                    "content": Self.buildPrompt(for: person, customPrompt: customPrompt)
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw OpenAIError.networkError(error)
        }

        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200...299:
                break
            case 401:
                throw OpenAIError.invalidAPIKey
            default:
                let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                    .flatMap { $0["error"] as? [String: Any] }
                    .flatMap { $0["message"] as? String }
                    ?? "HTTP \(http.statusCode)"
                throw OpenAIError.apiError(message)
            }
        }

        return try Self.parseResponse(data)
    }
}
