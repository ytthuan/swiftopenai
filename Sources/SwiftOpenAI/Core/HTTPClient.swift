import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Internal HTTP client that handles request building, execution, and response parsing.
///
/// Uses `URLSession` and Swift concurrency (async/await) for all network operations.
struct HTTPClient: Sendable {

    let session: URLSession
    let configuration: Configuration
    private let baseComponents: URLComponents
    private let basePath: String
    private let commonHeaders: [(field: String, value: String)]

    init(configuration: Configuration, session: URLSession? = nil) {
        self.configuration = configuration

        if let session {
            self.session = session
        } else {
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = configuration.timeoutInterval
            sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
            sessionConfig.httpMaximumConnectionsPerHost = 8
            #if canImport(Darwin)
            sessionConfig.timeoutIntervalForResource = min(configuration.timeoutInterval * 2, 1200)
            sessionConfig.waitsForConnectivity = true
            sessionConfig.urlCache = nil
            sessionConfig.httpShouldUsePipelining = true
            sessionConfig.httpShouldSetCookies = false
            sessionConfig.httpCookieAcceptPolicy = .never
            sessionConfig.tlsMinimumSupportedProtocolVersion = .TLSv12
            #else
            sessionConfig.httpShouldSetCookies = false
            #endif
            self.session = URLSession(configuration: sessionConfig)
        }

        // Cache base URL components to avoid re-parsing per request
        var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: true) ?? URLComponents()
        let path = components.path
        self.basePath = path.hasSuffix("/") ? path : path + "/"
        components.path = ""
        components.queryItems = nil
        self.baseComponents = components

        // Pre-build common headers (computed once, applied per-request)
        var headers: [(field: String, value: String)] = [
            ("Authorization", "Bearer \(configuration.apiKey)"),
            ("Accept-Encoding", "gzip, deflate"),
            ("Connection", "keep-alive"),
            ("User-Agent", SDK.userAgent),
        ]
        if let org = configuration.organization {
            headers.append(("OpenAI-Organization", Self.sanitizeHeaderValue(org)))
        }
        if let project = configuration.project {
            headers.append(("OpenAI-Project", Self.sanitizeHeaderValue(project)))
        }
        self.commonHeaders = headers
    }

    // MARK: - JSON Coding

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    // MARK: - Request Building

    /// Builds a URLRequest for the given path and method.
    func buildRequest(
        path: String,
        method: String = "GET",
        body: (any Encodable & Sendable)? = nil,
        queryItems: [URLQueryItem]? = nil
    ) throws -> URLRequest {
        var components = baseComponents
        components.path = basePath + path
        if let queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        for header in commonHeaders {
            request.setValue(header.value, forHTTPHeaderField: header.field)
        }

        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if let body {
            request.httpBody = try Self.encoder.encode(body)
        }

        return request
    }

    /// Builds a multipart/form-data request.
    func buildMultipartRequest(
        path: String,
        method: String = "POST",
        formData: MultipartFormData
    ) throws -> URLRequest {
        var components = baseComponents
        components.path = basePath + path

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        for header in commonHeaders {
            request.setValue(header.value, forHTTPHeaderField: header.field)
        }

        request.setValue(formData.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = formData.encode()
        return request
    }

    // MARK: - Header Sanitization

    /// Strips CR and LF characters to prevent HTTP header injection.
    private static func sanitizeHeaderValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }

    // MARK: - Request Execution

    /// Performs a request and decodes the JSON response.
    func perform<T: Decodable & Sendable>(request: URLRequest) async throws -> T {
        let (data, response) = try await performWithRetry(request: request) { req in
            try await session.data(for: req)
        }
        try validateResponse(data: data, response: response)
        return try Self.decoder.decode(T.self, from: data)
    }

    /// Performs a request and returns raw `Data` (for file downloads, audio, etc.).
    func performRaw(request: URLRequest) async throws -> Data {
        let (data, response) = try await performWithRetry(request: request) { req in
            try await session.data(for: req)
        }
        try validateResponse(data: data, response: response)
        return data
    }

    /// Performs a request with automatic retry for transient errors (429, 5xx).
    private func performWithRetry(request: URLRequest, operation: (URLRequest) async throws -> (Data, URLResponse)) async throws -> (Data, URLResponse) {
        let maxRetries = configuration.maxRetries
        for attempt in 0...maxRetries {
            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await operation(request)
            } catch let error as URLError {
                // Connection errors are not retryable
                throw mapURLError(error)
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                return (data, response)
            }

            let statusCode = httpResponse.statusCode
            let isRetryable = statusCode == 429 || statusCode >= 500
            let isLastAttempt = attempt == maxRetries

            if isRetryable && !isLastAttempt {
                let delay = retryDelay(for: attempt, response: httpResponse)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                continue
            }

            return (data, response)
        }
        // This should never be reached, but satisfy the compiler
        fatalError("Retry loop exited unexpectedly")
    }

    /// Calculates the retry delay for a given attempt, respecting Retry-After header.
    private func retryDelay(for attempt: Int, response: HTTPURLResponse) -> TimeInterval {
        // Respect Retry-After header if present (capped at 120s to prevent indefinite waits)
        if let retryAfterString = response.value(forHTTPHeaderField: "Retry-After"),
           let retryAfter = TimeInterval(retryAfterString) {
            return min(max(retryAfter, 0), 120)
        }
        // Exponential backoff with jitter (capped at 8s matching Python SDK MAX_RETRY_DELAY)
        let baseDelay = configuration.retryDelay * pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0...0.25)
        return min(baseDelay + jitter, 8)
    }

    /// Performs a streaming request and returns an SSE `AsyncSequence`.
    func performStream<T: Decodable & Sendable>(
        request: URLRequest
    ) async throws -> ServerSentEventsStream<T> {
        #if canImport(FoundationNetworking)
        // Linux: URLSession.AsyncBytes is unavailable in swift-corelibs-foundation.
        // Buffer the full response, then yield bytes. True incremental streaming
        // can be added via URLSessionDataDelegate in a future release.
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw mapURLError(error)
        }
        try validateResponse(data: data, response: response)
        let byteStream = AsyncThrowingStream<UInt8, Error> { continuation in
            for byte in data {
                continuation.yield(byte)
            }
            continuation.finish()
        }
        return ServerSentEventsStream<T>(byteStream: byteStream, decoder: Self.decoder)
        #else
        // Apple platforms: true incremental streaming via URLSession.AsyncBytes.
        let (bytes, response): (URLSession.AsyncBytes, URLResponse)
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch let error as URLError {
            throw mapURLError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.connectionError(message: "Bad server response")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            var errorData = Data()
            errorData.reserveCapacity(1024)
            for try await byte in bytes {
                errorData.append(byte)
            }
            throw try parseAPIError(data: errorData, statusCode: httpResponse.statusCode)
        }

        return ServerSentEventsStream<T>(bytes: bytes, response: response, decoder: Self.decoder)
        #endif
    }

    // MARK: - Convenience Methods

    /// GET request with JSON response.
    func get<T: Decodable & Sendable>(
        path: String,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        let request = try buildRequest(path: path, method: "GET", queryItems: queryItems)
        return try await perform(request: request)
    }

    /// POST request with JSON body and JSON response.
    func post<T: Decodable & Sendable>(
        path: String,
        body: (any Encodable & Sendable)? = nil
    ) async throws -> T {
        let request = try buildRequest(path: path, method: "POST", body: body)
        return try await perform(request: request)
    }

    /// DELETE request with JSON response.
    func delete<T: Decodable & Sendable>(path: String) async throws -> T {
        let request = try buildRequest(path: path, method: "DELETE")
        return try await perform(request: request)
    }

    /// POST multipart/form-data request with JSON response.
    func postMultipart<T: Decodable & Sendable>(
        path: String,
        formData: MultipartFormData
    ) async throws -> T {
        let request = try buildMultipartRequest(path: path, formData: formData)
        return try await perform(request: request)
    }

    /// POST multipart/form-data request returning raw data.
    func postMultipartRaw(
        path: String,
        formData: MultipartFormData
    ) async throws -> Data {
        let request = try buildMultipartRequest(path: path, formData: formData)
        return try await performRaw(request: request)
    }

    /// POST request with JSON body returning an SSE stream.
    func postStream<T: Decodable & Sendable>(
        path: String,
        body: (any Encodable & Sendable)? = nil
    ) async throws -> ServerSentEventsStream<T> {
        let request = try buildRequest(path: path, method: "POST", body: body)
        return try await performStream(request: request)
    }

    // MARK: - Validation & Error Parsing

    private func validateResponse(data: Data, response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.connectionError(message: "Bad server response")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw try parseAPIError(data: data, statusCode: httpResponse.statusCode)
        }
    }

    private func parseAPIError(data: Data, statusCode: Int) throws -> OpenAIError {
        let body = try? Self.decoder.decode(APIErrorBody.self, from: data)
        let message = body?.error.message ?? "Unknown error"

        switch statusCode {
        case 401:
            return .authenticationError(message: message)
        case 403:
            return .permissionDeniedError(message: message)
        case 409:
            return .conflictError(message: message)
        case 404:
            return .notFoundError(message: message)
        case 422:
            return .unprocessableEntityError(message: message)
        case 429:
            return .rateLimitError(message: message)
        case 500...:
            return .internalServerError(message: message)
        default:
            return .apiError(statusCode: statusCode, message: message, type: body?.error.type, code: body?.error.code)
        }
    }

    private func mapURLError(_ error: URLError) -> OpenAIError {
        switch error.code {
        case .timedOut:
            return .timeout
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
            return .connectionError(message: error.localizedDescription)
        default:
            return .connectionError(message: error.localizedDescription)
        }
    }
}

extension String {
    func validatePathComponent() throws -> String {
        guard !isEmpty else {
            throw OpenAIError.apiError(
                statusCode: 0,
                message: "Path component cannot be empty.",
                type: nil,
                code: nil
            )
        }
        guard !contains("/"), !contains("\\"), !contains("..") else {
            throw OpenAIError.apiError(
                statusCode: 0,
                message: "Path component contains invalid characters.",
                type: nil,
                code: nil
            )
        }
        return self
    }
}
