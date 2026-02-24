import Foundation

/// Access the OpenAI Models API.
///
/// List and describe the various models available in the API.
///
/// Usage:
/// ```swift
/// let models = try await client.models.list()
/// let model = try await client.models.retrieve("gpt-4o")
/// ```
public struct Models: Sendable {

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    /// Lists the currently available models.
    public func list() async throws -> ListResponse<Model> {
        try await client.get(path: "models")
    }

    /// Retrieves a model instance.
    ///
    /// - Parameter id: The ID of the model (e.g. "gpt-4o").
    public func retrieve(_ id: String) async throws -> Model {
        let validatedID = try id.validatePathComponent()
        return try await client.get(path: "models/\(validatedID)")
    }

    /// Deletes a fine-tuned model.
    ///
    /// - Parameter id: The model ID to delete.
    public func delete(_ id: String) async throws -> ModelDeleted {
        let validatedID = try id.validatePathComponent()
        return try await client.delete(path: "models/\(validatedID)")
    }
}
