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
}

/// A choice in a chat completion response.
public struct ChatCompletionChoice: Codable, Sendable {
    public let index: Int
    public let message: ChatCompletionResponseMessage
    public let finishReason: String?
    public let logprobs: ChatCompletionLogprobs?
}

/// The assistant's message in a completion response.
public struct ChatCompletionResponseMessage: Codable, Sendable {
    public let role: String
    public let content: String?
    public let toolCalls: [ChatCompletionToolCall]?
    public let refusal: String?
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
