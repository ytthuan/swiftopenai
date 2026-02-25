import Foundation

/// Access the OpenAI Chat Completions API.
///
/// Usage:
/// ```swift
/// let response = try await client.chat.completions.create(
///     model: "gpt-4o",
///     messages: [.user("Hello!")]
/// )
/// ```
public struct ChatCompletions: Sendable {

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    /// Creates a chat completion.
    ///
    /// - Parameters:
    ///   - model: ID of the model to use (e.g. "gpt-4o").
    ///   - messages: A list of messages comprising the conversation.
    ///   - temperature: Sampling temperature (0–2).
    ///   - topP: Nucleus sampling parameter.
    ///   - n: Number of completions to generate.
    ///   - stop: Stop sequences.
    ///   - maxCompletionTokens: Maximum number of tokens to generate.
    ///   - presencePenalty: Presence penalty (-2 to 2).
    ///   - frequencyPenalty: Frequency penalty (-2 to 2).
    ///   - logitBias: Token bias map.
    ///   - logprobs: Whether to return log probabilities.
    ///   - topLogprobs: Number of most likely tokens to return (0–20).
    ///   - user: End-user identifier.
    ///   - tools: Tools available to the model.
    ///   - toolChoice: Controls which tool is called.
    ///   - parallelToolCalls: Whether to enable parallel tool calls.
    ///   - seed: Deterministic sampling seed.
    ///   - responseFormat: Response format constraint.
    ///   - serviceTier: Service tier.
    ///   - store: Whether to store the completion.
    ///   - metadata: Metadata key-value pairs.
    public func create(
        model: String,
        messages: [ChatCompletionMessage],
        temperature: Double? = nil,
        topP: Double? = nil,
        n: Int? = nil,
        stop: ChatCompletionStop? = nil,
        maxCompletionTokens: Int? = nil,
        presencePenalty: Double? = nil,
        frequencyPenalty: Double? = nil,
        logitBias: [String: Int]? = nil,
        logprobs: Bool? = nil,
        topLogprobs: Int? = nil,
        user: String? = nil,
        tools: [ChatCompletionTool]? = nil,
        toolChoice: ChatCompletionToolChoice? = nil,
        parallelToolCalls: Bool? = nil,
        seed: Int? = nil,
        responseFormat: ChatCompletionResponseFormat? = nil,
        serviceTier: String? = nil,
        store: Bool? = nil,
        metadata: [String: String]? = nil
    ) async throws -> ChatCompletion {
        let params = ChatCompletionCreateParams(
            model: model,
            messages: messages,
            temperature: temperature,
            topP: topP,
            n: n,
            stream: nil,
            stop: stop,
            maxCompletionTokens: maxCompletionTokens,
            presencePenalty: presencePenalty,
            frequencyPenalty: frequencyPenalty,
            logitBias: logitBias,
            logprobs: logprobs,
            topLogprobs: topLogprobs,
            user: user,
            tools: tools,
            toolChoice: toolChoice,
            parallelToolCalls: parallelToolCalls,
            seed: seed,
            responseFormat: responseFormat,
            serviceTier: serviceTier,
            store: store,
            metadata: metadata
        )
        return try await client.post(path: "chat/completions", body: params)
    }

    /// Creates a streaming chat completion.
    ///
    /// Returns an `AsyncSequence` of `ChatCompletionChunk` values.
    public func createStream(
        model: String,
        messages: [ChatCompletionMessage],
        temperature: Double? = nil,
        topP: Double? = nil,
        n: Int? = nil,
        stop: ChatCompletionStop? = nil,
        maxCompletionTokens: Int? = nil,
        presencePenalty: Double? = nil,
        frequencyPenalty: Double? = nil,
        logitBias: [String: Int]? = nil,
        logprobs: Bool? = nil,
        topLogprobs: Int? = nil,
        user: String? = nil,
        tools: [ChatCompletionTool]? = nil,
        toolChoice: ChatCompletionToolChoice? = nil,
        parallelToolCalls: Bool? = nil,
        seed: Int? = nil,
        responseFormat: ChatCompletionResponseFormat? = nil,
        serviceTier: String? = nil,
        store: Bool? = nil,
        metadata: [String: String]? = nil
    ) async throws -> ServerSentEventsStream<ChatCompletionChunk> {
        let params = ChatCompletionCreateParams(
            model: model,
            messages: messages,
            temperature: temperature,
            topP: topP,
            n: n,
            stream: true,
            stop: stop,
            maxCompletionTokens: maxCompletionTokens,
            presencePenalty: presencePenalty,
            frequencyPenalty: frequencyPenalty,
            logitBias: logitBias,
            logprobs: logprobs,
            topLogprobs: topLogprobs,
            user: user,
            tools: tools,
            toolChoice: toolChoice,
            parallelToolCalls: parallelToolCalls,
            seed: seed,
            responseFormat: responseFormat,
            serviceTier: serviceTier,
            store: store,
            metadata: metadata
        )
        return try await client.postStream(path: "chat/completions", body: params)
    }
}
