import Foundation

/// Access the OpenAI Files API.
///
/// Upload files for use with fine-tuning, assistants, and other features.
///
/// Usage:
/// ```swift
/// let file = try await client.files.create(
///     file: fileData,
///     filename: "training.jsonl",
///     purpose: "fine-tune"
/// )
/// ```
public struct Files: Sendable {

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    /// Uploads a file.
    ///
    /// - Parameters:
    ///   - file: The file data to upload.
    ///   - filename: The name of the file.
    ///   - purpose: The intended purpose (e.g. "fine-tune", "assistants", "batch").
    /// - Returns: The uploaded file object.
    public func create(
        file: Data,
        filename: String,
        purpose: String
    ) async throws -> FileObject {
        var formData = MultipartFormData()
        formData.addFile(name: "file", filename: filename, mimeType: "application/octet-stream", data: file)
        formData.addField(name: "purpose", value: purpose)
        return try await client.postMultipart(path: "files", formData: formData)
    }

    /// Retrieves a file object.
    ///
    /// - Parameter id: The ID of the file to retrieve.
    /// - Returns: The file object.
    public func retrieve(_ id: String) async throws -> FileObject {
        let validatedID = try id.validatePathComponent()
        return try await client.get(path: "files/\(validatedID)")
    }

    /// Returns a list of files.
    ///
    /// - Parameters:
    ///   - after: A cursor for pagination.
    ///   - limit: Maximum number of files to return.
    ///   - purpose: Filter files by purpose.
    ///   - order: Sort order (`"asc"` or `"desc"`).
    /// - Returns: A list response containing file objects.
    public func list(
        after: String? = nil,
        limit: Int? = nil,
        purpose: String? = nil,
        order: String? = nil
    ) async throws -> ListResponse<FileObject> {
        var queryItems: [URLQueryItem] = []
        if let after { queryItems.append(URLQueryItem(name: "after", value: after)) }
        if let limit { queryItems.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let purpose { queryItems.append(URLQueryItem(name: "purpose", value: purpose)) }
        if let order { queryItems.append(URLQueryItem(name: "order", value: order)) }
        return try await client.get(path: "files", queryItems: queryItems.isEmpty ? nil : queryItems)
    }

    /// Deletes a file.
    ///
    /// - Parameter id: The ID of the file to delete.
    /// - Returns: The deletion confirmation.
    public func delete(_ id: String) async throws -> FileDeleted {
        let validatedID = try id.validatePathComponent()
        return try await client.delete(path: "files/\(validatedID)")
    }

    /// Returns the contents of a file as raw data.
    ///
    /// - Parameter id: The ID of the file whose content to retrieve.
    /// - Returns: The raw file data.
    public func content(_ id: String) async throws -> Data {
        let validatedID = try id.validatePathComponent()
        let request = try client.buildRequest(path: "files/\(validatedID)/content", method: "GET")
        return try await client.performRaw(request: request)
    }
}
