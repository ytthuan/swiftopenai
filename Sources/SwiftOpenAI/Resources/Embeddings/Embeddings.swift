import Foundation

/// Access the OpenAI Embeddings API.
///
/// Get a vector representation of a given input.
///
/// Usage:
/// ```swift
/// let response = try await client.embeddings.create(
///     model: "text-embedding-3-small",
///     input: .string("Hello world")
/// )
/// ```
public struct Embeddings: Sendable {

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    /// Creates an embedding vector representing the input text.
    ///
    /// - Parameters:
    ///   - model: ID of the model to use (e.g. "text-embedding-3-small").
    ///   - input: Input text to embed.
    ///   - dimensions: The number of dimensions for the output embeddings.
    ///   - encodingFormat: The format to return embeddings in.
    ///   - user: A unique identifier representing your end-user.
    /// - Returns: A ``CreateEmbeddingResponse`` containing the embedding vectors.
    public func create(
        model: String,
        input: EmbeddingInput,
        dimensions: Int? = nil,
        encodingFormat: String? = nil,
        user: String? = nil
    ) async throws -> CreateEmbeddingResponse {
        let body = CreateEmbeddingRequest(
            input: input,
            model: model,
            dimensions: dimensions,
            encodingFormat: encodingFormat,
            user: user
        )
        return try await client.post(path: "embeddings", body: body)
    }
}
