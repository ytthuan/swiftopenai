import Foundation

/// A completion response (legacy API).
public struct Completion: Codable, Sendable {
    /// Unique identifier for the completion.
    public let id: String
    /// The object type, always `"text_completion"`.
    public let object: String
    /// Unix timestamp of when the completion was created.
    public let created: Int
    /// The model used for the completion.
    public let model: String
    /// The list of completion choices.
    public let choices: [CompletionChoice]
    /// Token usage statistics.
    public let usage: Usage?
    /// A fingerprint representing the backend configuration.
    public let systemFingerprint: String?
}

/// A choice in a completion response.
public struct CompletionChoice: Codable, Sendable {
    /// The index of this choice in the list.
    public let index: Int
    /// The generated text.
    public let text: String
    /// Log probability information.
    public let logprobs: CompletionLogprobs?
    /// The reason the model stopped generating tokens.
    public let finishReason: String?
}

/// A streamed completion chunk.
public struct CompletionChunk: Codable, Sendable {
    /// Unique identifier for the completion.
    public let id: String
    /// The object type for the chunk.
    public let object: String
    /// Unix timestamp of when the chunk was created.
    public let created: Int
    /// The model used for the completion.
    public let model: String
    /// The list of streamed chunk choices.
    public let choices: [CompletionChunkChoice]
}

/// A choice in a streamed completion chunk.
public struct CompletionChunkChoice: Codable, Sendable {
    /// The index of this choice in the list.
    public let index: Int
    /// The generated text fragment.
    public let text: String
    /// The reason the model stopped generating tokens.
    public let finishReason: String?
}

/// Log probabilities for a completion.
public struct CompletionLogprobs: Codable, Sendable {
    /// The tokens in the completion.
    public let tokens: [String]?
    /// The log probabilities of the tokens.
    public let tokenLogprobs: [Double]?
    /// The top log probabilities for each token position.
    public let topLogprobs: [[String: Double]]?
    /// The text offsets of each token.
    public let textOffset: [Int]?
}

/// Parameters for creating a completion.
struct CompletionCreateParams: Encodable, Sendable {
    let model: String
    let prompt: CompletionPrompt?
    let maxTokens: Int?
    let temperature: Double?
    let topP: Double?
    let n: Int?
    let stream: Bool? = nil
    let logprobs: Int?
    let stop: CompletionStop?
    let presencePenalty: Double?
    let frequencyPenalty: Double?
    let bestOf: Int?
    let user: String?
    let suffix: String?
    let echo: Bool?
    let seed: Int?
}

/// Prompt input — single string or array of strings.
public enum CompletionPrompt: Encodable, Sendable {
    case string(String)
    case strings([String])

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .strings(let values): try container.encode(values)
        }
    }
}

/// Stop sequence — single string or array of strings.
public enum CompletionStop: Encodable, Sendable {
    case string(String)
    case strings([String])

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .strings(let values): try container.encode(values)
        }
    }
}
