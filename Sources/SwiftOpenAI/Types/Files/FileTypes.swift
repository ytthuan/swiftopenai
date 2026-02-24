import Foundation

/// A file object from the OpenAI API.
public struct FileObject: Codable, Sendable, Identifiable {
    public let id: String
    public let object: String
    public let bytes: Int
    public let createdAt: Int
    public let filename: String
    public let purpose: String
    public let status: String?
}

/// Response when deleting a file.
public struct FileDeleted: Codable, Sendable {
    public let id: String
    public let object: String
    public let deleted: Bool
}
