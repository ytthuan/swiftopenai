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
            sessionConfig.timeoutIntervalForResource = configuration.timeoutInterval * 2
            sessionConfig.waitsForConnectivity = true
            sessionConfig.urlCache = nil
            sessionConfig.httpShouldUsePipelining = true
            sessionConfig.httpShouldSetCookies = false
            sessionConfig.httpCookieAcceptPolicy = .never
            sessionConfig.tlsMinimumSupportedProtocolVersion = .TLSv12
            #endif
            self.session = URLSession(configuration: sessionConfig)
        }
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
        let baseString = configuration.baseURL.absoluteString
        let separator = baseString.hasSuffix("/") ? "" : "/"
        var urlComponents = URLComponents(string: baseString + separator + path)
        if let queryItems, !queryItems.isEmpty {
            urlComponents?.queryItems = queryItems
        }

        guard let url = urlComponents?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.setValue("SwiftOpenAI/0.4.0", forHTTPHeaderField: "User-Agent")

        if let org = configuration.organization {
            request.setValue(org, forHTTPHeaderField: "OpenAI-Organization")
        }
        if let project = configuration.project {
            request.setValue(project, forHTTPHeaderField: "OpenAI-Project")
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
        let baseString = configuration.baseURL.absoluteString
        let separator = baseString.hasSuffix("/") ? "" : "/"
        guard let url = URL(string: baseString + separator + path) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(formData.contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.setValue("SwiftOpenAI/0.4.0", forHTTPHeaderField: "User-Agent")

        if let org = configuration.organization {
            request.setValue(org, forHTTPHeaderField: "OpenAI-Organization")
        }
        if let project = configuration.project {
            request.setValue(project, forHTTPHeaderField: "OpenAI-Project")
        }

        request.httpBody = formData.encode()
        return request
    }

    // MARK: - Request Execution

    /// Performs a request and decodes the JSON response.
    func perform<T: Decodable & Sendable>(request: URLRequest) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw mapURLError(error)
        }
        try validateResponse(data: data, response: response)
        return try Self.decoder.decode(T.self, from: data)
    }

    /// Performs a request and returns raw `Data` (for file downloads, audio, etc.).
    func performRaw(request: URLRequest) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw mapURLError(error)
        }
        try validateResponse(data: data, response: response)
        return data
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
