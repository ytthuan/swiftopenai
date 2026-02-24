import Foundation

/// Access the OpenAI Responses API.
///
/// Create model responses with tool use and structured output.
///
/// Usage:
/// ```swift
/// let response = try await client.responses.create(
///     model: "gpt-4o",
///     input: .text("Hello!")
/// )
/// ```
public struct Responses: Sendable {

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    // MARK: - Create

    /// Creates a model response.
    ///
    /// - Parameters:
    ///   - model: The model to use (e.g. `"gpt-4o"`).
    ///   - input: The input text or messages.
    ///   - instructions: Optional system instructions.
    ///   - maxOutputTokens: Maximum number of output tokens.
    ///   - temperature: Sampling temperature (0–2).
    ///   - topP: Nucleus sampling parameter.
    ///   - store: Whether to store the response for later retrieval.
    ///   - metadata: Arbitrary key-value metadata to attach.
    ///   - previousResponseId: The ID of a previous response for multi-turn conversation.
    ///   - tools: Tools the model can use (functions, web search, etc.).
    ///   - toolChoice: Controls which tool the model should use.
    ///   - text: Text output format configuration (for structured outputs).
    ///   - truncation: Truncation strategy (`"auto"` or `"disabled"`).
    ///   - contextManagement: Context management configuration (compaction).
    ///   - reasoning: Reasoning configuration for o-series models.
    ///   - parallelToolCalls: Whether to allow parallel tool calls.
    ///   - maxToolCalls: Maximum number of tool calls.
    ///   - serviceTier: The service tier to use.
    /// - Returns: The created `Response`.
    public func create(
        model: String,
        input: ResponseInput,
        instructions: String? = nil,
        maxOutputTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        store: Bool? = nil,
        metadata: [String: String]? = nil,
        previousResponseId: String? = nil,
        tools: [ResponseTool]? = nil,
        toolChoice: ResponseToolChoice? = nil,
        text: ResponseTextConfig? = nil,
        truncation: String? = nil,
        contextManagement: [ContextManagement]? = nil,
        reasoning: ReasoningConfig? = nil,
        parallelToolCalls: Bool? = nil,
        maxToolCalls: Int? = nil,
        serviceTier: String? = nil
    ) async throws -> Response {
        let params = ResponseCreateParams(
            model: model,
            input: input,
            instructions: instructions,
            maxOutputTokens: maxOutputTokens,
            temperature: temperature,
            topP: topP,
            stream: nil,
            store: store,
            metadata: metadata,
            previousResponseId: previousResponseId,
            tools: tools,
            toolChoice: toolChoice,
            text: text,
            truncation: truncation,
            contextManagement: contextManagement,
            reasoning: reasoning,
            parallelToolCalls: parallelToolCalls,
            maxToolCalls: maxToolCalls,
            serviceTier: serviceTier
        )
        return try await client.post(path: "responses", body: params)
    }

    // MARK: - Stream

    /// Creates a streaming model response.
    ///
    /// Returns an `AsyncSequence` of `ResponseStreamEvent` values that arrive
    /// incrementally as the model generates output.
    ///
    /// - Parameters:
    ///   - model: The model to use (e.g. `"gpt-4o"`).
    ///   - input: The input text or messages.
    ///   - instructions: Optional system instructions.
    ///   - maxOutputTokens: Maximum number of output tokens.
    ///   - temperature: Sampling temperature (0–2).
    ///   - topP: Nucleus sampling parameter.
    ///   - previousResponseId: The ID of a previous response for multi-turn conversation.
    ///   - tools: Tools the model can use (functions, web search, etc.).
    ///   - toolChoice: Controls which tool the model should use.
    ///   - text: Text output format configuration (for structured outputs).
    ///   - truncation: Truncation strategy.
    ///   - contextManagement: Context management configuration (compaction).
    ///   - reasoning: Reasoning configuration for o-series models.
    ///   - parallelToolCalls: Whether to allow parallel tool calls.
    ///   - maxToolCalls: Maximum number of tool calls.
    ///   - serviceTier: The service tier to use.
    /// - Returns: An `AsyncSequence` of `ResponseStreamEvent` values.
    public func createStream(
        model: String,
        input: ResponseInput,
        instructions: String? = nil,
        maxOutputTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        previousResponseId: String? = nil,
        tools: [ResponseTool]? = nil,
        toolChoice: ResponseToolChoice? = nil,
        text: ResponseTextConfig? = nil,
        truncation: String? = nil,
        contextManagement: [ContextManagement]? = nil,
        reasoning: ReasoningConfig? = nil,
        parallelToolCalls: Bool? = nil,
        maxToolCalls: Int? = nil,
        serviceTier: String? = nil
    ) async throws -> ServerSentEventsStream<ResponseStreamEvent> {
        let params = ResponseCreateParams(
            model: model,
            input: input,
            instructions: instructions,
            maxOutputTokens: maxOutputTokens,
            temperature: temperature,
            topP: topP,
            stream: true,
            store: nil,
            metadata: nil,
            previousResponseId: previousResponseId,
            tools: tools,
            toolChoice: toolChoice,
            text: text,
            truncation: truncation,
            contextManagement: contextManagement,
            reasoning: reasoning,
            parallelToolCalls: parallelToolCalls,
            maxToolCalls: maxToolCalls,
            serviceTier: serviceTier
        )
        return try await client.postStream(path: "responses", body: params)
    }

    // MARK: - Retrieve

    /// Retrieves a response by ID.
    ///
    /// - Parameter id: The response ID to retrieve.
    /// - Returns: The retrieved `Response`.
    public func retrieve(_ id: String) async throws -> Response {
        try await client.get(path: "responses/\(id)")
    }

    // MARK: - Delete

    /// Deletes a response by ID.
    ///
    /// - Parameter id: The response ID to delete.
    /// - Returns: The deleted `ResponseDeleted`.
    public func delete(_ id: String) async throws -> ResponseDeleted {
        try await client.delete(path: "responses/\(id)")
    }

    // MARK: - Compact

    /// Compacts a conversation context to reduce token usage.
    ///
    /// Use this for long-running conversations to keep context within token limits.
    ///
    /// - Parameters:
    ///   - model: The model to use for compaction.
    ///   - input: The conversation input to compact.
    ///   - instructions: Optional system instructions.
    ///   - previousResponseId: The ID of a previous response to compact from.
    /// - Returns: The compacted response with reduced context.
    public func compact(
        model: String,
        input: ResponseInput? = nil,
        instructions: String? = nil,
        previousResponseId: String? = nil
    ) async throws -> CompactedResponse {
        let params = ResponseCompactParams(
            model: model,
            input: input,
            instructions: instructions,
            previousResponseId: previousResponseId
        )
        return try await client.post(path: "responses/compact", body: params)
    }
}
