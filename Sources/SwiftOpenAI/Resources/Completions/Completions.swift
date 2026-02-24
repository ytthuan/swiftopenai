import Foundation

/// Access the OpenAI Completions API (legacy).
///
/// For most use cases, prefer the Chat Completions API instead.
public struct Completions: Sendable {

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    /// Creates a completion for the provided prompt.
    ///
    /// - Parameters:
    ///   - model: ID of the model to use.
    ///   - prompt: The prompt to generate completions for.
    ///   - maxTokens: Maximum number of tokens to generate.
    ///   - temperature: Sampling temperature (0–2).
    ///   - topP: Nucleus sampling parameter.
    ///   - n: Number of completions to generate.
    ///   - stop: Stop sequences.
    ///   - presencePenalty: Presence penalty (−2 to 2).
    ///   - frequencyPenalty: Frequency penalty (−2 to 2).
    ///   - user: End-user identifier.
    ///   - suffix: Suffix for inserted text.
    ///   - seed: Deterministic sampling seed.
    /// - Returns: A ``Completion`` containing the generated text.
    public func create(
        model: String,
        prompt: CompletionPrompt? = nil,
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        n: Int? = nil,
        stop: CompletionStop? = nil,
        presencePenalty: Double? = nil,
        frequencyPenalty: Double? = nil,
        user: String? = nil,
        suffix: String? = nil,
        seed: Int? = nil
    ) async throws -> Completion {
        let params = CompletionCreateParams(
            model: model,
            prompt: prompt,
            maxTokens: maxTokens,
            temperature: temperature,
            topP: topP,
            n: n,
            stream: nil,
            logprobs: nil,
            stop: stop,
            presencePenalty: presencePenalty,
            frequencyPenalty: frequencyPenalty,
            bestOf: nil,
            user: user,
            suffix: suffix,
            echo: nil,
            seed: seed
        )
        return try await client.post(path: "completions", body: params)
    }
}
