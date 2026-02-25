import Foundation

/// A streamed chunk of a chat completion response.
public struct ChatCompletionChunk: Codable, Sendable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [ChatCompletionChunkChoice]
    public let usage: Usage?
    public let systemFingerprint: String?

    private enum CodingKeys: String, CodingKey {
        case id, object, created, model, choices, usage, systemFingerprint
    }
}

/// A choice within a streamed chunk.
public struct ChatCompletionChunkChoice: Codable, Sendable {
    public let index: Int
    public let delta: ChatCompletionDelta?
    public let finishReason: String?

    private enum CodingKeys: String, CodingKey {
        case index, delta, finishReason
    }
}

/// The delta content in a streamed chunk.
public struct ChatCompletionDelta: Codable, Sendable {
    public let role: String?
    public let content: String?
    public let toolCalls: [ChatCompletionToolCallDelta]?

    private enum CodingKeys: String, CodingKey {
        case role, content, toolCalls
    }
}

/// A partial tool call delta in a streamed chunk.
public struct ChatCompletionToolCallDelta: Codable, Sendable {
    public let index: Int
    public let id: String?
    public let type: String?
    public let function: FunctionCallDelta?
}

/// A partial function call in a streamed chunk.
public struct FunctionCallDelta: Codable, Sendable {
    public let name: String?
    public let arguments: String?
}
