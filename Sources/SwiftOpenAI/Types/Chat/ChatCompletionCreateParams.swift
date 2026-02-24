import Foundation

/// Request parameters for creating a chat completion.
public struct ChatCompletionCreateParams: Encodable, Sendable {
    public let model: String
    public let messages: [ChatCompletionMessage]
    public let temperature: Double?
    public let topP: Double?
    public let n: Int?
    public let stream: Bool?
    public let stop: ChatCompletionStop?
    public let maxCompletionTokens: Int?
    public let presencePenalty: Double?
    public let frequencyPenalty: Double?
    public let logitBias: [String: Int]?
    public let logprobs: Bool?
    public let topLogprobs: Int?
    public let user: String?
    public let tools: [ChatCompletionTool]?
    public let toolChoice: ChatCompletionToolChoice?
    public let parallelToolCalls: Bool?
    public let seed: Int?
    public let responseFormat: ChatCompletionResponseFormat?
    public let serviceTier: String?
    public let store: Bool?
    public let metadata: [String: String]?
}

/// Stop sequence — a single string or array of strings.
public enum ChatCompletionStop: Encodable, Sendable {
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

/// A tool available to the model.
public struct ChatCompletionTool: Encodable, Sendable {
    public let type: String
    public let function: ChatCompletionToolFunction

    public init(function: ChatCompletionToolFunction) {
        self.type = "function"
        self.function = function
    }
}

/// A function definition for tool use.
public struct ChatCompletionToolFunction: Encodable, Sendable {
    public let name: String
    public let description: String?
    public let parameters: [String: AnyCodable]?

    public init(name: String, description: String? = nil, parameters: [String: AnyCodable]? = nil) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

/// Tool choice — auto, none, required, or a specific function.
public enum ChatCompletionToolChoice: Encodable, Sendable {
    case auto
    case none
    case required
    case function(String)

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .auto:
            var container = encoder.singleValueContainer()
            try container.encode("auto")
        case .none:
            var container = encoder.singleValueContainer()
            try container.encode("none")
        case .required:
            var container = encoder.singleValueContainer()
            try container.encode("required")
        case .function(let name):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("function", forKey: .type)
            try container.encode(["name": name], forKey: .function)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, function
    }
}

/// Response format for structured output.
public enum ChatCompletionResponseFormat: Encodable, Sendable {
    case text
    case jsonObject

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text: try container.encode("text", forKey: .type)
        case .jsonObject: try container.encode("json_object", forKey: .type)
        }
    }

    private enum CodingKeys: String, CodingKey { case type }
}

/// Type-erased Codable value for JSON schema parameters.
public struct AnyCodable: Encodable, Sendable {
    private let _encode: @Sendable (Encoder) throws -> Void

    public init<T: Encodable & Sendable>(_ value: T) {
        self._encode = { encoder in try value.encode(to: encoder) }
    }

    public func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
