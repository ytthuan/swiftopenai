import Foundation

/// A chat completion response.
public struct ChatCompletion: Codable, Sendable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [ChatCompletionChoice]
    public let usage: Usage?
    public let systemFingerprint: String?
    public let serviceTier: String?

    /// Creates a `ChatCompletion` instance (useful for testing).
    public init(
        id: String,
        object: String = "chat.completion",
        created: Int,
        model: String,
        choices: [ChatCompletionChoice],
        usage: Usage? = nil,
        systemFingerprint: String? = nil,
        serviceTier: String? = nil
    ) {
        self.id = id
        self.object = object
        self.created = created
        self.model = model
        self.choices = choices
        self.usage = usage
        self.systemFingerprint = systemFingerprint
        self.serviceTier = serviceTier
    }
}

/// A choice in a chat completion response.
public struct ChatCompletionChoice: Codable, Sendable {
    public let index: Int
    public let message: ChatCompletionResponseMessage
    public let finishReason: String?
    public let logprobs: ChatCompletionLogprobs?

    public init(index: Int, message: ChatCompletionResponseMessage, finishReason: String? = nil, logprobs: ChatCompletionLogprobs? = nil) {
        self.index = index
        self.message = message
        self.finishReason = finishReason
        self.logprobs = logprobs
    }
}

/// The assistant's message in a completion response.
public struct ChatCompletionResponseMessage: Codable, Sendable {
    public let role: String
    public let content: String?
    public let toolCalls: [ChatCompletionToolCall]?
    public let refusal: String?

    public init(role: String = "assistant", content: String?, toolCalls: [ChatCompletionToolCall]? = nil, refusal: String? = nil) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.refusal = refusal
    }
}

/// Log probabilities for a completion.
public struct ChatCompletionLogprobs: Codable, Sendable {
    public let content: [ChatCompletionTokenLogprob]?
}

/// A single token's log probability.
public struct ChatCompletionTokenLogprob: Codable, Sendable {
    public let token: String
    public let logprob: Double
    public let bytes: [Int]?
}
