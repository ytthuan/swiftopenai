import Foundation

/// Errors thrown by the SwiftOpenAI client.
public enum OpenAIError: Error, Sendable {

    /// The API returned an error response.
    case apiError(statusCode: Int, message: String, type: String?, code: String?)

    /// Authentication failed (401).
    case authenticationError(message: String)

    /// Permission denied (403).
    case permissionDeniedError(message: String)

    /// Resource not found (404).
    case notFoundError(message: String)

    /// Rate limit exceeded (429).
    case rateLimitError(message: String)

    /// Unprocessable entity (422).
    case unprocessableEntityError(message: String)

    /// Internal server error (>= 500).
    case internalServerError(message: String)

    /// Network or connection error.
    case connectionError(underlyingError: Error)

    /// Request timed out.
    case timeout
}

/// The error body returned by the OpenAI API.
public struct APIErrorBody: Codable, Sendable {
    public let error: APIErrorDetail
}

/// Detail of an API error.
public struct APIErrorDetail: Codable, Sendable {
    public let message: String
    public let type: String?
    public let param: String?
    public let code: String?
}
