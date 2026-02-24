import Foundation

/// Represents an OpenAI model.
public struct Model: Codable, Sendable, Identifiable {
    public let id: String
    public let object: String
    public let created: Int
    public let ownedBy: String
}

/// Response from deleting a model.
public struct ModelDeleted: Codable, Sendable {
    public let id: String
    public let object: String
    public let deleted: Bool
}
