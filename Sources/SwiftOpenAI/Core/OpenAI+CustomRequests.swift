import Foundation

extension OpenAI {
    /// Sends a GET request to a custom endpoint and decodes its JSON response.
    ///
    /// Paths are relative to `configuration.baseURL`. One leading slash is allowed
    /// and preserves the base URL's path. Pass an unescaped path and supply query
    /// parameters separately; absolute URLs, dot segments, and embedded queries or
    /// fragments are rejected. Authentication, retries, and errors follow the
    /// client's configuration. Responses use the SDK's snake-case decoding rules;
    /// use `JSONValue` to preserve arbitrary JSON object keys.
    ///
    /// - Parameters:
    ///   - path: The endpoint path relative to the configured base URL.
    ///   - queryItems: Query parameters appended after the client's default query items.
    /// - Returns: The decoded JSON response. Empty or malformed responses throw a decoding error.
    public func get<Response: Decodable & Sendable>(
        _ path: String,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> Response {
        try await customRequest(path: path, method: "GET", queryItems: queryItems)
    }

    /// Sends a POST request to a custom endpoint and decodes its JSON response.
    ///
    /// Uses the relative-path, authentication, retry, and decoding behavior of `get(_:queryItems:)`.
    /// Encodable properties use the SDK's snake-case encoding rules; `JSONValue`
    /// preserves arbitrary object keys. A nil body omits the body and content type.
    ///
    /// - Parameters:
    ///   - path: An unescaped endpoint path relative to the configured base URL.
    ///   - body: An optional JSON request body.
    ///   - queryItems: Query parameters appended after the client's default query items.
    /// - Returns: The decoded JSON response. Empty or malformed responses throw a decoding error.
    public func post<Response: Decodable & Sendable>(
        _ path: String,
        body: (any Encodable & Sendable)? = nil,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> Response {
        try await customRequest(path: path, method: "POST", body: body, queryItems: queryItems)
    }

    /// Sends a PUT request to a custom endpoint and decodes its JSON response.
    ///
    /// Uses the relative-path, JSON coding, authentication, and retry behavior of `post(_:body:queryItems:)`.
    ///
    /// - Parameters:
    ///   - path: An unescaped endpoint path relative to the configured base URL.
    ///   - body: An optional JSON request body.
    ///   - queryItems: Query parameters appended after the client's default query items.
    /// - Returns: The decoded JSON response. Empty or malformed responses throw a decoding error.
    public func put<Response: Decodable & Sendable>(
        _ path: String,
        body: (any Encodable & Sendable)? = nil,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> Response {
        try await customRequest(path: path, method: "PUT", body: body, queryItems: queryItems)
    }

    /// Sends a PATCH request to a custom endpoint and decodes its JSON response.
    ///
    /// Uses the relative-path, JSON coding, authentication, and retry behavior of `post(_:body:queryItems:)`.
    ///
    /// - Parameters:
    ///   - path: An unescaped endpoint path relative to the configured base URL.
    ///   - body: An optional JSON request body.
    ///   - queryItems: Query parameters appended after the client's default query items.
    /// - Returns: The decoded JSON response. Empty or malformed responses throw a decoding error.
    public func patch<Response: Decodable & Sendable>(
        _ path: String,
        body: (any Encodable & Sendable)? = nil,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> Response {
        try await customRequest(path: path, method: "PATCH", body: body, queryItems: queryItems)
    }

    /// Sends a DELETE request to a custom endpoint and decodes its JSON response.
    ///
    /// Uses the relative-path, JSON coding, authentication, and retry behavior of `post(_:body:queryItems:)`.
    ///
    /// - Parameters:
    ///   - path: An unescaped endpoint path relative to the configured base URL.
    ///   - body: An optional JSON request body.
    ///   - queryItems: Query parameters appended after the client's default query items.
    /// - Returns: The decoded JSON response. Empty or malformed responses throw a decoding error.
    public func delete<Response: Decodable & Sendable>(
        _ path: String,
        body: (any Encodable & Sendable)? = nil,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> Response {
        try await customRequest(path: path, method: "DELETE", body: body, queryItems: queryItems)
    }

    private func customRequest<Response: Decodable & Sendable>(
        path: String,
        method: String,
        body: (any Encodable & Sendable)? = nil,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> Response {
        let relativePath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let segments = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard !relativePath.hasPrefix("/"),
              URLComponents(string: path)?.scheme == nil,
              !path.contains("\\"), !path.contains("?"), !path.contains("#"), !path.contains("%"),
              path.rangeOfCharacter(from: .controlCharacters) == nil,
              !segments.contains("."), !segments.contains("..") else {
            throw OpenAIError.apiError(
                statusCode: 0,
                message: "Custom request paths must be relative, unescaped paths without queries, fragments, or dot segments.",
                type: nil,
                code: nil
            )
        }
        let request = try httpClient.buildRequest(
            path: relativePath, method: method, body: body, queryItems: queryItems
        )
        return try await httpClient.perform(request: request)
    }
}
