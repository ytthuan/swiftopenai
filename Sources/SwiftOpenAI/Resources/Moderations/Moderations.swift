import Foundation

/// Access the OpenAI Moderations API.
///
/// Classifies if text is potentially harmful.
///
/// Usage:
/// ```swift
/// let result = try await client.moderations.create(input: .string("some text"))
/// ```
public struct Moderations: Sendable {

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    /// Classifies if text is potentially harmful.
    ///
    /// - Parameters:
    ///   - input: The input text to classify.
    ///   - model: The moderation model to use (optional, auto-selects if omitted).
    /// - Returns: A ``ModerationCreateResponse`` containing the classification results.
    public func create(
        input: ModerationInput,
        model: String? = nil
    ) async throws -> ModerationCreateResponse {
        let body = ModerationCreateRequest(input: input, model: model)
        return try await client.post(path: "moderations", body: body)
    }
}
