import Foundation

/// Represents an OpenAI model.
public struct Model: Codable, Sendable, Identifiable {
    public let id: String
    public let object: String
    public let created: Int
    public let ownedBy: String
}
