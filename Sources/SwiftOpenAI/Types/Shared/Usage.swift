import Foundation

/// Token usage information returned by many API endpoints.
public struct Usage: Codable, Sendable {
    public let promptTokens: Int
    public let completionTokens: Int?
    public let totalTokens: Int
}
