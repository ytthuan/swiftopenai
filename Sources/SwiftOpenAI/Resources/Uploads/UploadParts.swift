import Foundation

/// Access upload part operations.
public struct UploadParts: Sendable {

    private let client: HTTPClient

    init(client: HTTPClient) { self.client = client }

    /// Adds a part to an upload.
    ///
    /// - Parameters:
    ///   - uploadId: The ID of the upload.
    ///   - data: The chunk of bytes for this part.
    /// - Returns: The created ``UploadPart`` object.
    public func create(uploadId: String, data: Data) async throws -> UploadPart {
        var formData = MultipartFormData()
        formData.addFile(name: "data", filename: "part", mimeType: "application/octet-stream", data: data)
        return try await client.postMultipart(path: "uploads/\(uploadId)/parts", formData: formData)
    }
}
