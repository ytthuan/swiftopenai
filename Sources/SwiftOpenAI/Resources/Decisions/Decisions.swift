import Foundation

/// Access the Decisions API for classification, predicates, and rubric scoring.
public struct Decisions: Sendable {
    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    /// Evaluates all questions against the shared input and returns ordered answers.
    ///
    /// - Parameter request: Complete Decisions input, questions, and optional settings.
    /// - Returns: Typed answers, including per-question refusals, and token usage.
    public func create(request: DecisionCreateRequest) async throws -> Decision {
        try await client.post(path: "decisions", body: request)
    }

    /// Evaluates classification or scoring questions against shared evidence.
    ///
    /// - Parameters:
    ///   - model: The model ID; currently the service supports `gpt-6-luna`.
    ///   - input: Plain text or ordered messages and tool history.
    ///   - questions: Between 1 and 400 questions, evaluated in the supplied order.
    ///   - promptCacheKey: Optional caller-provided key partitioning cache reuse.
    ///   - promptCacheOptions: Optional prompt-cache mode and lifetime settings.
    ///   - safetyIdentifier: Optional opaque end-user identifier for safety monitoring.
    /// - Returns: Typed answers and complete token usage.
    public func create(
        model: String,
        input: DecisionInput,
        questions: [DecisionQuestion],
        promptCacheKey: String? = nil,
        promptCacheOptions: PromptCacheOptions? = nil,
        safetyIdentifier: String? = nil
    ) async throws -> Decision {
        try await create(request: DecisionCreateRequest(
            model: model,
            input: input,
            questions: questions,
            promptCacheKey: promptCacheKey,
            promptCacheOptions: promptCacheOptions,
            safetyIdentifier: safetyIdentifier
        ))
    }
}
