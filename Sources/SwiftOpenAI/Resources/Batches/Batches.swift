import Foundation

/// Access the OpenAI Batches API.
///
/// Create and manage batch processing jobs.
public struct Batches: Sendable {

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    /// Creates a batch.
    ///
    /// - Parameters:
    ///   - inputFileId: The ID of the input file for the batch.
    ///   - endpoint: The API endpoint to use for the batch (e.g. "/v1/chat/completions").
    ///   - completionWindow: The time window for batch completion (default: "24h").
    ///   - metadata: Optional metadata for the batch.
    /// - Returns: The created `Batch` object.
    public func create(
        inputFileId: String,
        endpoint: String,
        completionWindow: String = "24h",
        metadata: [String: String]? = nil
    ) async throws -> Batch {
        let params = BatchCreateParams(
            inputFileId: inputFileId,
            endpoint: endpoint,
            completionWindow: completionWindow,
            metadata: metadata
        )
        return try await client.post(path: "batches", body: params)
    }

    /// Retrieves a batch by ID.
    ///
    /// - Parameter id: The batch ID.
    /// - Returns: The `Batch` object.
    public func retrieve(_ id: String) async throws -> Batch {
        let validatedID = try id.validatePathComponent()
        return try await client.get(path: "batches/\(validatedID)")
    }

    /// Lists batches.
    ///
    /// - Parameters:
    ///   - after: A cursor for pagination.
    ///   - limit: Maximum number of batches to return.
    /// - Returns: A paginated list of `Batch` objects.
    public func list(after: String? = nil, limit: Int? = nil) async throws -> ListResponse<Batch> {
        var queryItems: [URLQueryItem] = []
        if let after { queryItems.append(URLQueryItem(name: "after", value: after)) }
        if let limit { queryItems.append(URLQueryItem(name: "limit", value: String(limit))) }
        return try await client.get(path: "batches", queryItems: queryItems.isEmpty ? nil : queryItems)
    }

    /// Cancels a batch.
    ///
    /// - Parameter id: The batch ID to cancel.
    /// - Returns: The cancelled `Batch` object.
    public func cancel(_ id: String) async throws -> Batch {
        let validatedID = try id.validatePathComponent()
        return try await client.post(path: "batches/\(validatedID)/cancel")
    }
}
