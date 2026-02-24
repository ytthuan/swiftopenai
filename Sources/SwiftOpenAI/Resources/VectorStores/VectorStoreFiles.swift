import Foundation

/// Access vector store file operations.
public struct VectorStoreFiles: Sendable {

    private let client: HTTPClient

    init(client: HTTPClient) { self.client = client }

    /// Adds a file to a vector store.
    ///
    /// - Parameters:
    ///   - vectorStoreId: The ID of the vector store.
    ///   - fileId: The ID of the file to add.
    /// - Returns: The created ``VectorStoreFile``.
    public func create(vectorStoreId: String, fileId: String) async throws -> VectorStoreFile {
        struct Params: Encodable, Sendable { let fileId: String }
        return try await client.post(
            path: "vector_stores/\(vectorStoreId)/files",
            body: Params(fileId: fileId)
        )
    }

    /// Retrieves a file from a vector store.
    ///
    /// - Parameters:
    ///   - vectorStoreId: The ID of the vector store.
    ///   - fileId: The ID of the file to retrieve.
    /// - Returns: The ``VectorStoreFile``.
    public func retrieve(vectorStoreId: String, fileId: String) async throws -> VectorStoreFile {
        try await client.get(path: "vector_stores/\(vectorStoreId)/files/\(fileId)")
    }

    /// Lists files in a vector store.
    ///
    /// - Parameters:
    ///   - vectorStoreId: The ID of the vector store.
    ///   - after: A cursor for pagination.
    ///   - limit: Maximum number of results to return.
    /// - Returns: A ``ListResponse`` of ``VectorStoreFile`` objects.
    public func list(
        vectorStoreId: String,
        after: String? = nil,
        limit: Int? = nil
    ) async throws -> ListResponse<VectorStoreFile> {
        var queryItems: [URLQueryItem] = []
        if let after { queryItems.append(URLQueryItem(name: "after", value: after)) }
        if let limit { queryItems.append(URLQueryItem(name: "limit", value: String(limit))) }
        return try await client.get(
            path: "vector_stores/\(vectorStoreId)/files",
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
    }

    /// Removes a file from a vector store.
    ///
    /// - Parameters:
    ///   - vectorStoreId: The ID of the vector store.
    ///   - fileId: The ID of the file to remove.
    /// - Returns: A ``VectorStoreFileDeleted`` confirmation.
    public func delete(vectorStoreId: String, fileId: String) async throws -> VectorStoreFileDeleted {
        try await client.delete(path: "vector_stores/\(vectorStoreId)/files/\(fileId)")
    }
}
