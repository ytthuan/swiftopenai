import Foundation

/// A vector store.
public struct VectorStore: Codable, Sendable, Identifiable {
    public let id: String
    public let object: String
    public let createdAt: Int
    public let name: String?
    public let description: String?
    public let status: String
    public let usageBytes: Int?
    public let fileCounts: VectorStoreFileCounts?
    public let expiresAfter: VectorStoreExpirationPolicy?
    public let expiresAt: Int?
    public let lastActiveAt: Int?
    public let metadata: [String: String]?
}

/// File counts in a vector store.
public struct VectorStoreFileCounts: Codable, Sendable {
    public let inProgress: Int
    public let completed: Int
    public let failed: Int
    public let cancelled: Int
    public let total: Int
}

/// Expiration policy for a vector store.
public struct VectorStoreExpirationPolicy: Codable, Sendable {
    public let anchor: String
    public let days: Int
}

/// Response when deleting a vector store.
public struct VectorStoreDeleted: Codable, Sendable {
    public let id: String
    public let object: String
    public let deleted: Bool
}

/// A file in a vector store.
public struct VectorStoreFile: Codable, Sendable, Identifiable {
    public let id: String
    public let object: String
    public let createdAt: Int
    public let vectorStoreId: String
    public let status: String
    public let usageBytes: Int?
    public let lastError: VectorStoreFileError?
}

/// An error from a vector store file.
public struct VectorStoreFileError: Codable, Sendable {
    public let code: String
    public let message: String
}

/// Response when deleting a vector store file.
public struct VectorStoreFileDeleted: Codable, Sendable {
    public let id: String
    public let object: String
    public let deleted: Bool
}

/// Parameters for creating a vector store.
struct VectorStoreCreateParams: Encodable, Sendable {
    let name: String?
    let description: String?
    let fileIds: [String]?
    let expiresAfter: VectorStoreExpirationPolicy?
    let metadata: [String: String]?
}

/// Parameters for updating a vector store.
struct VectorStoreUpdateParams: Encodable, Sendable {
    let name: String?
    let description: String?
    let expiresAfter: VectorStoreExpirationPolicy?
    let metadata: [String: String]?
}

/// Parameters for searching a vector store.
struct VectorStoreSearchParams: Encodable, Sendable {
    let query: String
    let maxResults: Int?
}

/// A vector store search response.
public struct VectorStoreSearchResponse: Codable, Sendable {
    public let object: String
    public let data: [VectorStoreSearchResult]
}

/// A single search result.
public struct VectorStoreSearchResult: Codable, Sendable {
    public let fileId: String
    public let filename: String?
    public let score: Double
    public let content: [VectorStoreSearchContent]?
}

/// Content from a search result.
public struct VectorStoreSearchContent: Codable, Sendable {
    public let type: String
    public let text: String?
}
