import Foundation

/// A batch object.
public struct Batch: Codable, Sendable, Identifiable {
    public let id: String
    public let object: String
    public let endpoint: String
    public let inputFileId: String
    public let completionWindow: String
    public let status: String
    public let outputFileId: String?
    public let errorFileId: String?
    public let createdAt: Int
    public let inProgressAt: Int?
    public let expiresAt: Int?
    public let finalizingAt: Int?
    public let completedAt: Int?
    public let failedAt: Int?
    public let expiredAt: Int?
    public let cancellingAt: Int?
    public let cancelledAt: Int?
    public let requestCounts: BatchRequestCounts?
    public let errors: BatchErrors?
    public let metadata: [String: String]?
}

/// Request counts for a batch.
public struct BatchRequestCounts: Codable, Sendable {
    public let total: Int
    public let completed: Int
    public let failed: Int
}

/// Errors in a batch.
public struct BatchErrors: Codable, Sendable {
    public let object: String?
    public let data: [BatchError]?
}

/// A single batch error.
public struct BatchError: Codable, Sendable {
    public let code: String?
    public let message: String?
    public let param: String?
    public let line: Int?
}

/// Parameters for creating a batch.
struct BatchCreateParams: Encodable, Sendable {
    let inputFileId: String
    let endpoint: String
    let completionWindow: String
    let metadata: [String: String]?
}
