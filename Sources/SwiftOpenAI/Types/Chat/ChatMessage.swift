import Foundation

/// A message in a chat completion request.
public enum ChatCompletionMessage: Codable, Sendable {
    case system(String)
    case user(String)
    case assistant(String, toolCalls: [ChatCompletionToolCall]? = nil)
    case tool(String, toolCallId: String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let role = try container.decode(String.self, forKey: .role)
        switch role {
        case "system":
            let content = try container.decode(String.self, forKey: .content)
            self = .system(content)
        case "user":
            let content = try container.decode(String.self, forKey: .content)
            self = .user(content)
        case "assistant":
            let content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
            let toolCalls = try container.decodeIfPresent([ChatCompletionToolCall].self, forKey: .toolCalls)
            self = .assistant(content, toolCalls: toolCalls)
        case "tool":
            let content = try container.decode(String.self, forKey: .content)
            let toolCallId = try container.decode(String.self, forKey: .toolCallId)
            self = .tool(content, toolCallId: toolCallId)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .role, in: container,
                debugDescription: "Unknown role: \(role)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .system(let content):
            try container.encode("system", forKey: .role)
            try container.encode(content, forKey: .content)
        case .user(let content):
            try container.encode("user", forKey: .role)
            try container.encode(content, forKey: .content)
        case .assistant(let content, let toolCalls):
            try container.encode("assistant", forKey: .role)
            try container.encode(content, forKey: .content)
            try container.encodeIfPresent(toolCalls, forKey: .toolCalls)
        case .tool(let content, let toolCallId):
            try container.encode("tool", forKey: .role)
            try container.encode(content, forKey: .content)
            try container.encode(toolCallId, forKey: .toolCallId)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case role, content, toolCalls, toolCallId
    }
}

/// A tool call made by the assistant.
public struct ChatCompletionToolCall: Codable, Sendable {
    public let id: String
    public let type: String
    public let function: FunctionCall

    public init(id: String, type: String = "function", function: FunctionCall) {
        self.id = id
        self.type = type
        self.function = function
    }
}

/// A function call within a tool call.
public struct FunctionCall: Codable, Sendable {
    public let name: String
    public let arguments: String

    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }
}
