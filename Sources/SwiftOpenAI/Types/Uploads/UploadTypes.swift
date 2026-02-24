import Foundation

/// An upload object.
public struct Upload: Codable, Sendable, Identifiable {
    public let id: String
    public let object: String
    public let bytes: Int
    public let createdAt: Int
    public let filename: String
    public let purpose: String
    public let status: String
    public let expiresAt: Int?
    public let file: FileObject?
}

/// An upload part.
public struct UploadPart: Codable, Sendable, Identifiable {
    public let id: String
    public let object: String
    public let createdAt: Int
    public let uploadId: String
}

/// Parameters for creating an upload.
struct UploadCreateParams: Encodable, Sendable {
    let filename: String
    let purpose: String
    let bytes: Int
    let mimeType: String
}

/// Parameters for completing an upload.
struct UploadCompleteParams: Encodable, Sendable {
    let partIds: [String]
    let md5: String?
}
