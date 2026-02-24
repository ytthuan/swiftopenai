import Foundation

/// Generic list response from the OpenAI API.
public struct ListResponse<T: Codable & Sendable>: Codable, Sendable {
    public let object: String
    public let data: [T]
    public let hasMore: Bool?
    public let firstId: String?
    public let lastId: String?
}
