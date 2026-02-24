import Foundation

/// Access the OpenAI Uploads API.
///
/// Upload large files in parts.
public struct Uploads: Sendable {

    private let client: HTTPClient

    /// Access upload parts.
    public let parts: UploadParts

    init(client: HTTPClient) {
        self.client = client
        self.parts = UploadParts(client: client)
    }

    /// Creates an upload.
    ///
    /// - Parameters:
    ///   - filename: The name of the file to upload.
    ///   - purpose: The intended purpose of the uploaded file.
    ///   - bytes: The number of bytes in the file you are uploading.
    ///   - mimeType: The MIME type of the file.
    /// - Returns: The created ``Upload`` object.
    public func create(
        filename: String,
        purpose: String,
        bytes: Int,
        mimeType: String
    ) async throws -> Upload {
        let params = UploadCreateParams(
            filename: filename, purpose: purpose,
            bytes: bytes, mimeType: mimeType
        )
        return try await client.post(path: "uploads", body: params)
    }

    /// Cancels an upload.
    ///
    /// - Parameter id: The ID of the upload to cancel.
    /// - Returns: The cancelled ``Upload`` object.
    public func cancel(_ id: String) async throws -> Upload {
        let validatedID = try id.validatePathComponent()
        return try await client.post(path: "uploads/\(validatedID)/cancel", body: nil as String?)
    }

    /// Completes an upload.
    ///
    /// - Parameters:
    ///   - id: The ID of the upload to complete.
    ///   - partIds: The ordered list of part IDs.
    ///   - md5: Optional MD5 checksum for verification.
    /// - Returns: The completed ``Upload`` object.
    public func complete(_ id: String, partIds: [String], md5: String? = nil) async throws -> Upload {
        let validatedID = try id.validatePathComponent()
        let params = UploadCompleteParams(partIds: partIds, md5: md5)
        return try await client.post(path: "uploads/\(validatedID)/complete", body: params)
    }
}
