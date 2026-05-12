import Foundation

// MARK: - ChatCompletionCreateParams

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
    public let serviceTier: ServiceTier?
    public let store: Bool?
    public let metadata: [String: String]?
    // v0.10.0 additions
    public let reasoningEffort: ReasoningEffort?
    public let streamOptions: ChatCompletionStreamOptions?
    public let verbosity: Verbosity?
    public let promptCacheKey: String?
    public let promptCacheRetention: PromptCacheRetention?
    public let safetyIdentifier: String?
    public let webSearchOptions: WebSearchOptions?
    public let prediction: ChatCompletionPredictionContent?

    /// Creates chat completion request parameters.
    ///
    /// All parameters after `messages` are optional and default to `nil`.
    /// New v0.10.0 parameters are appended at the end.
    public init(
        model: String,
        messages: [ChatCompletionMessage],
        temperature: Double? = nil,
        topP: Double? = nil,
        n: Int? = nil,
        stream: Bool? = nil,
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
        serviceTier: ServiceTier? = nil,
        store: Bool? = nil,
        metadata: [String: String]? = nil,
        reasoningEffort: ReasoningEffort? = nil,
        streamOptions: ChatCompletionStreamOptions? = nil,
        verbosity: Verbosity? = nil,
        promptCacheKey: String? = nil,
        promptCacheRetention: PromptCacheRetention? = nil,
        safetyIdentifier: String? = nil,
        webSearchOptions: WebSearchOptions? = nil,
        prediction: ChatCompletionPredictionContent? = nil
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.topP = topP
        self.n = n
        self.stream = stream
        self.stop = stop
        self.maxCompletionTokens = maxCompletionTokens
        self.presencePenalty = presencePenalty
        self.frequencyPenalty = frequencyPenalty
        self.logitBias = logitBias
        self.logprobs = logprobs
        self.topLogprobs = topLogprobs
        self.user = user
        self.tools = tools
        self.toolChoice = toolChoice
        self.parallelToolCalls = parallelToolCalls
        self.seed = seed
        self.responseFormat = responseFormat
        self.serviceTier = serviceTier
        self.store = store
        self.metadata = metadata
        self.reasoningEffort = reasoningEffort
        self.streamOptions = streamOptions
        self.verbosity = verbosity
        self.promptCacheKey = promptCacheKey
        self.promptCacheRetention = promptCacheRetention
        self.safetyIdentifier = safetyIdentifier
        self.webSearchOptions = webSearchOptions
        self.prediction = prediction
    }
}

// MARK: - ChatCompletionStop

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

// MARK: - ChatCompletionTool

/// A tool available to the model.
///
/// Supports function tools and custom tools. Existing call sites using
/// `ChatCompletionTool(function:)` continue to work unchanged.
///
/// Wire format:
/// - `.function(...)` → `{"type":"function","function":{...}}`
/// - `.custom(...)` → `{"type":"custom","custom":{...}}`
public enum ChatCompletionTool: Encodable, Sendable {
    /// A function tool the model can call.
    case function(ChatCompletionToolFunction)
    /// A custom tool with user-defined format.
    case custom(ChatCompletionCustomTool)

    /// Backward-compatible convenience initializer for function tools.
    public init(function: ChatCompletionToolFunction) {
        self = .function(function)
    }

    /// Convenience initializer for custom tools.
    public init(custom: ChatCompletionCustomTool) {
        self = .custom(custom)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .function(let function):
            try container.encode("function", forKey: .type)
            try container.encode(function, forKey: .function)
        case .custom(let custom):
            try container.encode("custom", forKey: .type)
            try container.encode(custom, forKey: .custom)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, function, custom
    }

    /// The tool type (`"function"` or `"custom"`).
    /// Backward-compatible accessor for code written against the v0.9.x struct API.
    public var type: String {
        switch self {
        case .function: return "function"
        case .custom: return "custom"
        }
    }

    /// The function definition, if this is a `.function` tool. Returns `nil` for `.custom` tools.
    /// Backward-compatible accessor for code written against the v0.9.x struct API.
    public var function: ChatCompletionToolFunction? {
        switch self {
        case .function(let f): return f
        case .custom: return nil
        }
    }

    /// The custom tool definition, if this is a `.custom` tool. Returns `nil` for `.function` tools.
    public var custom: ChatCompletionCustomTool? {
        switch self {
        case .function: return nil
        case .custom(let c): return c
        }
    }
}

// MARK: - ChatCompletionToolFunction

/// A function definition for tool use.
public struct ChatCompletionToolFunction: Encodable, Sendable {
    public let name: String
    public let description: String?
    public let parameters: [String: AnyCodable]?
    /// Whether to enable strict schema adherence for the function parameters.
    public let strict: Bool?

    public init(
        name: String,
        description: String? = nil,
        parameters: [String: AnyCodable]? = nil,
        strict: Bool? = nil
    ) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.strict = strict
    }
}

// MARK: - ChatCompletionToolChoice

/// Tool choice — auto, none, required, a specific function, custom tool, or allowed tools.
public enum ChatCompletionToolChoice: Encodable, Sendable {
    case auto
    case none
    case required
    /// Call a specific function by name.
    case function(String)
    /// Call a specific custom tool by name.
    case custom(String)
    /// Restrict available tools to a filtered set.
    case allowedTools(mode: AllowedToolsMode, tools: [ChatCompletionTool])

    /// Mode for allowed tools filtering.
    public enum AllowedToolsMode: String, Encodable, Sendable {
        case auto
        case required
    }

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
        case .custom(let name):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("custom", forKey: .type)
            try container.encode(["name": name], forKey: .custom)
        case .allowedTools(let mode, let tools):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("allowed_tools", forKey: .type)
            var allowedContainer = container.nestedContainer(
                keyedBy: AllowedToolsCodingKeys.self, forKey: .allowedTools
            )
            try allowedContainer.encode(mode, forKey: .mode)
            try allowedContainer.encode(tools, forKey: .tools)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, function, custom, allowedTools
    }

    private enum AllowedToolsCodingKeys: String, CodingKey {
        case mode, tools
    }
}

// MARK: - ChatCompletionResponseFormat

/// Response format for structured output.
public enum ChatCompletionResponseFormat: Encodable, Sendable {
    case text
    case jsonObject
    /// Structured output with a JSON schema.
    case jsonSchema(name: String, schema: [String: AnyCodable], strict: Bool? = nil, description: String? = nil)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text:
            try container.encode("text", forKey: .type)
        case .jsonObject:
            try container.encode("json_object", forKey: .type)
        case .jsonSchema(let name, let schema, let strict, let description):
            try container.encode("json_schema", forKey: .type)
            var schemaContainer = container.nestedContainer(keyedBy: JsonSchemaCodingKeys.self, forKey: .jsonSchema)
            try schemaContainer.encode(name, forKey: .name)
            try schemaContainer.encode(schema, forKey: .schema)
            try schemaContainer.encodeIfPresent(strict, forKey: .strict)
            try schemaContainer.encodeIfPresent(description, forKey: .description)
        }
    }

    private enum CodingKeys: String, CodingKey { case type, jsonSchema }
    private enum JsonSchemaCodingKeys: String, CodingKey { case name, schema, strict, description }
}

// MARK: - ReasoningEffort

/// Reasoning effort level for the model.
///
/// Controls how much reasoning the model performs. Higher values produce
/// more thorough reasoning at the cost of additional tokens and latency.
///
/// - Note: The `.disabled` case encodes to `"none"` on the wire. It was renamed
///   from `.none` to avoid collision with `Optional.none` at call sites
///   (e.g. `reasoningEffort: .none` silently resolves to `nil`).
public enum ReasoningEffort: Codable, Sendable, Hashable, Equatable {
    /// Disable reasoning entirely. Wire value: `"none"`.
    case disabled
    case minimal
    case low
    case medium
    case high
    case xhigh
    /// Forward-compatible case for unknown effort levels.
    case other(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "none": self = .disabled
        case "minimal": self = .minimal
        case "low": self = .low
        case "medium": self = .medium
        case "high": self = .high
        case "xhigh": self = .xhigh
        default: self = .other(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .disabled: try container.encode("none")
        case .minimal: try container.encode("minimal")
        case .low: try container.encode("low")
        case .medium: try container.encode("medium")
        case .high: try container.encode("high")
        case .xhigh: try container.encode("xhigh")
        case .other(let value): try container.encode(value)
        }
    }
}

// MARK: - Verbosity

/// Verbosity level for the model response.
public enum Verbosity: Codable, Sendable, Hashable, Equatable {
    case low
    case medium
    case high
    /// Forward-compatible case for unknown verbosity levels.
    case other(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "low": self = .low
        case "medium": self = .medium
        case "high": self = .high
        default: self = .other(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .low: try container.encode("low")
        case .medium: try container.encode("medium")
        case .high: try container.encode("high")
        case .other(let value): try container.encode(value)
        }
    }
}

// MARK: - PromptCacheRetention

/// Prompt cache retention policy.
public enum PromptCacheRetention: Codable, Sendable, Hashable, Equatable {
    /// Keep the prompt cached in memory.
    case inMemory
    /// Retain the prompt cache for 24 hours.
    case h24
    /// Forward-compatible case for unknown retention policies.
    case other(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "in_memory": self = .inMemory
        case "24h": self = .h24
        default: self = .other(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .inMemory: try container.encode("in_memory")
        case .h24: try container.encode("24h")
        case .other(let value): try container.encode(value)
        }
    }
}

// MARK: - AnyCodable

/// Type-erased Codable value for JSON schema parameters.
public struct AnyCodable: Codable, Sendable {
    private let _encode: @Sendable (Encoder) throws -> Void

    public init<T: Encodable & Sendable>(_ value: T) {
        self._encode = { encoder in try value.encode(to: encoder) }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.init(Optional<String>.none as String?)
            return
        }
        if let bool = try? container.decode(Bool.self) {
            self.init(bool)
            return
        }
        if let int = try? container.decode(Int.self) {
            self.init(int)
            return
        }
        if let double = try? container.decode(Double.self) {
            self.init(double)
            return
        }
        if let string = try? container.decode(String.self) {
            self.init(string)
            return
        }
        if let array = try? container.decode([AnyCodable].self) {
            self.init(array)
            return
        }
        if let object = try? container.decode([String: AnyCodable].self) {
            self.init(object)
            return
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
    }

    public func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
