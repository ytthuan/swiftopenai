import Foundation

/// Access the OpenAI Vector Stores API.
public struct VectorStores: Sendable {

    private let client: HTTPClient

    /// Access vector store files.
    public let files: VectorStoreFiles

    init(client: HTTPClient) {
        self.client = client
        self.files = VectorStoreFiles(client: client)
    }

    /// Creates a vector store.
    ///
    /// - Parameters:
    ///   - name: A name for the vector store.
    ///   - description: A description of the vector store.
    ///   - fileIds: A list of file IDs to add to the vector store.
    ///   - expiresAfter: The expiration policy for the vector store.
    ///   - metadata: Optional metadata key-value pairs.
    /// - Returns: The created ``VectorStore``.
    public func create(
        name: String? = nil,
        description: String? = nil,
        fileIds: [String]? = nil,
        expiresAfter: VectorStoreExpirationPolicy? = nil,
        metadata: [String: String]? = nil
    ) async throws -> VectorStore {
        let params = VectorStoreCreateParams(
            name: name, description: description,
            fileIds: fileIds, expiresAfter: expiresAfter, metadata: metadata
        )
        return try await client.post(path: "vector_stores", body: params)
    }

    /// Retrieves a vector store.
    ///
    /// - Parameter id: The ID of the vector store to retrieve.
    /// - Returns: The ``VectorStore``.
    public func retrieve(_ id: String) async throws -> VectorStore {
        try await client.get(path: "vector_stores/\(id)")
    }

    /// Updates a vector store.
    ///
    /// - Parameters:
    ///   - id: The ID of the vector store to update.
    ///   - name: A new name for the vector store.
    ///   - description: A new description for the vector store.
    ///   - expiresAfter: Updated expiration policy.
    ///   - metadata: Updated metadata key-value pairs.
    /// - Returns: The updated ``VectorStore``.
    public func update(
        _ id: String,
        name: String? = nil,
        description: String? = nil,
        expiresAfter: VectorStoreExpirationPolicy? = nil,
        metadata: [String: String]? = nil
    ) async throws -> VectorStore {
        let params = VectorStoreUpdateParams(
            name: name, description: description,
            expiresAfter: expiresAfter, metadata: metadata
        )
        return try await client.post(path: "vector_stores/\(id)", body: params)
    }

    /// Lists vector stores.
    ///
    /// - Parameters:
    ///   - after: A cursor for pagination.
    ///   - limit: Maximum number of results to return.
    /// - Returns: A ``ListResponse`` of ``VectorStore`` objects.
    public func list(after: String? = nil, limit: Int? = nil) async throws -> ListResponse<VectorStore> {
        var queryItems: [URLQueryItem] = []
        if let after { queryItems.append(URLQueryItem(name: "after", value: after)) }
        if let limit { queryItems.append(URLQueryItem(name: "limit", value: String(limit))) }
        return try await client.get(path: "vector_stores", queryItems: queryItems.isEmpty ? nil : queryItems)
    }

    /// Deletes a vector store.
    ///
    /// - Parameter id: The ID of the vector store to delete.
    /// - Returns: A ``VectorStoreDeleted`` confirmation.
    public func delete(_ id: String) async throws -> VectorStoreDeleted {
        try await client.delete(path: "vector_stores/\(id)")
    }

    /// Searches a vector store.
    ///
    /// - Parameters:
    ///   - id: The ID of the vector store to search.
    ///   - query: The search query string.
    ///   - maxResults: Maximum number of results to return.
    /// - Returns: A ``VectorStoreSearchResponse`` containing search results.
    public func search(
        _ id: String,
        query: String,
        maxResults: Int? = nil
    ) async throws -> VectorStoreSearchResponse {
        let params = VectorStoreSearchParams(query: query, maxResults: maxResults)
        return try await client.post(path: "vector_stores/\(id)/search", body: params)
    }
}
