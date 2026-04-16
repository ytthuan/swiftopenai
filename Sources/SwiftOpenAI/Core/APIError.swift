import Foundation

/// Errors thrown by the SwiftOpenAI client.
public enum OpenAIError: Error, Sendable {

    /// The API returned an error response.
    case apiError(statusCode: Int, message: String, type: String?, code: String?)

    /// Authentication failed (401).
    case authenticationError(message: String)

    /// Permission denied (403).
    case permissionDeniedError(message: String)

    /// Conflict (409).
    case conflictError(message: String)

    /// Resource not found (404).
    case notFoundError(message: String)

    /// Rate limit exceeded (429).
    case rateLimitError(message: String)

    /// Unprocessable entity (422).
    case unprocessableEntityError(message: String)

    /// Internal server error (>= 500).
    case internalServerError(message: String)

    /// Network or connection error.
    case connectionError(message: String)

    /// Failed to decode response data.
    case decodingError(message: String)

    /// Request timed out.
    case timeout

    /// SSE buffer exceeded maximum allowed size.
    case bufferOverflow(message: String)
}

extension OpenAIError: Equatable {
    public static func == (lhs: OpenAIError, rhs: OpenAIError) -> Bool {
        switch (lhs, rhs) {
        case (.apiError(let ls, let lm, let lt, let lc), .apiError(let rs, let rm, let rt, let rc)):
            return ls == rs && lm == rm && lt == rt && lc == rc
        case (.authenticationError(let l), .authenticationError(let r)):
            return l == r
        case (.permissionDeniedError(let l), .permissionDeniedError(let r)):
            return l == r
        case (.conflictError(let l), .conflictError(let r)):
            return l == r
        case (.notFoundError(let l), .notFoundError(let r)):
            return l == r
        case (.rateLimitError(let l), .rateLimitError(let r)):
            return l == r
        case (.unprocessableEntityError(let l), .unprocessableEntityError(let r)):
            return l == r
        case (.internalServerError(let l), .internalServerError(let r)):
            return l == r
        case (.connectionError(let l), .connectionError(let r)):
            return l == r
        case (.decodingError(let l), .decodingError(let r)):
            return l == r
        case (.timeout, .timeout):
            return true
        case (.bufferOverflow(let l), .bufferOverflow(let r)):
            return l == r
        default:
            return false
        }
    }
}

extension OpenAIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .apiError(_, let message, _, _):
            return message
        case .authenticationError(let message):
            return message
        case .permissionDeniedError(let message):
            return message
        case .conflictError(let message):
            return message
        case .notFoundError(let message):
            return message
        case .rateLimitError(let message):
            return message
        case .unprocessableEntityError(let message):
            return message
        case .internalServerError(let message):
            return message
        case .connectionError(let message):
            return message
        case .decodingError(let message):
            return message
        case .timeout:
            return "Request timed out."
        case .bufferOverflow(let message):
            return message
        }
    }
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
