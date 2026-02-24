import Foundation

/// Internal HTTP client that handles request building, execution, and response parsing.
///
/// Uses `URLSession` and Swift concurrency (async/await) for all network operations.
struct HTTPClient: Sendable {

    private let session: URLSession
    private let configuration: Configuration

    init(configuration: Configuration) {
        self.configuration = configuration

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeoutInterval
        self.session = URLSession(configuration: sessionConfig)
    }

    // MARK: - Request Building

    /// Builds a URLRequest for the given path and method.
    func buildRequest(
        path: String,
        method: String = "GET",
        body: (any Encodable & Sendable)? = nil,
        queryItems: [URLQueryItem]? = nil
    ) throws -> URLRequest {
        var urlComponents = URLComponents(
            url: configuration.baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: true
        )
        urlComponents?.queryItems = queryItems

        guard let url = urlComponents?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let org = configuration.organization {
            request.setValue(org, forHTTPHeaderField: "OpenAI-Organization")
        }
        if let project = configuration.project {
            request.setValue(project, forHTTPHeaderField: "OpenAI-Project")
        }

        if let body {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(body)
        }

        return request
    }

    // MARK: - Request Execution

    /// Performs a request and decodes the response.
    func perform<T: Decodable & Sendable>(request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.connectionError(underlyingError: URLError(.badServerResponse))
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw try parseAPIError(data: data, statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Error Parsing

    private func parseAPIError(data: Data, statusCode: Int) throws -> OpenAIError {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let body = try? decoder.decode(APIErrorBody.self, from: data)
        let message = body?.error.message ?? "Unknown error"
        let type = body?.error.type
        let code = body?.error.code

        switch statusCode {
        case 401:
            return .authenticationError(message: message)
        case 403:
            return .permissionDeniedError(message: message)
        case 404:
            return .notFoundError(message: message)
        case 422:
            return .unprocessableEntityError(message: message)
        case 429:
            return .rateLimitError(message: message)
        case 500...:
            return .internalServerError(message: message)
        default:
            return .apiError(statusCode: statusCode, message: message, type: type, code: code)
        }
    }
}
