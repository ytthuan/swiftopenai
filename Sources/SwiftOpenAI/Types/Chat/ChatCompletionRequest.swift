import Foundation

// MARK: - Request Content

/// A structured Chat Completions request content part.
///
/// Typed factories cover the currently supported content variants, while
/// `init(jsonValue:)` preserves forward-compatible or vendor-specific objects.
public struct ChatCompletionRequestContentPart: Codable, Sendable, Equatable {
    /// The complete JSON representation of the content part.
    public let jsonValue: JSONValue

    /// Creates a dynamic content part from its complete JSON representation.
    public init(jsonValue: JSONValue) {
        self.jsonValue = jsonValue
    }

    /// Bridges a legacy content part without changing its wire shape.
    public init(_ contentPart: ChatCompletionContentPart) {
        switch contentPart {
        case .text(let text):
            self = .text(text)
        case .imageURL(let imageURL):
            self = .imageURL(imageURL)
        case .other(let type):
            self.init(jsonValue: .object(["type": .string(type)]))
        }
    }

    /// Creates a text content part.
    public static func text(
        _ text: String,
        promptCacheBreakpoint: PromptCacheBreakpoint? = nil
    ) -> Self {
        Self(jsonValue: object(
            type: "text",
            fields: ["text": .string(text)],
            promptCacheBreakpoint: promptCacheBreakpoint
        ))
    }

    /// Creates an image URL content part.
    public static func imageURL(
        _ imageURL: ChatCompletionImageURL,
        promptCacheBreakpoint: PromptCacheBreakpoint? = nil
    ) -> Self {
        var image: [String: JSONValue] = ["url": .string(imageURL.url)]
        if let detail = imageURL.detail {
            image["detail"] = .string(detail.wireValue)
        }
        return Self(jsonValue: object(
            type: "image_url",
            fields: ["image_url": .object(image)],
            promptCacheBreakpoint: promptCacheBreakpoint
        ))
    }

    /// Creates an input-audio content part.
    ///
    /// - Parameters:
    ///   - data: Base64-encoded audio bytes.
    ///   - format: Audio format, such as `"wav"` or `"mp3"`.
    ///   - promptCacheBreakpoint: Optional explicit prompt-cache boundary.
    public static func inputAudio(
        data: String,
        format: String,
        promptCacheBreakpoint: PromptCacheBreakpoint? = nil
    ) -> Self {
        Self(jsonValue: object(
            type: "input_audio",
            fields: [
                "input_audio": .object([
                    "data": .string(data),
                    "format": .string(format),
                ]),
            ],
            promptCacheBreakpoint: promptCacheBreakpoint
        ))
    }

    /// Creates an inline file content part.
    ///
    /// - Parameters:
    ///   - data: Base64-encoded file data.
    ///   - filename: Optional filename associated with the data.
    ///   - promptCacheBreakpoint: Optional explicit prompt-cache boundary.
    public static func file(
        data: String,
        filename: String? = nil,
        promptCacheBreakpoint: PromptCacheBreakpoint? = nil
    ) -> Self {
        var file: [String: JSONValue] = ["file_data": .string(data)]
        if let filename {
            file["filename"] = .string(filename)
        }
        return Self(jsonValue: object(
            type: "file",
            fields: ["file": .object(file)],
            promptCacheBreakpoint: promptCacheBreakpoint
        ))
    }

    /// Creates an uploaded-file content part.
    public static func file(
        id: String,
        promptCacheBreakpoint: PromptCacheBreakpoint? = nil
    ) -> Self {
        Self(jsonValue: object(
            type: "file",
            fields: ["file": .object(["file_id": .string(id)])],
            promptCacheBreakpoint: promptCacheBreakpoint
        ))
    }

    public init(from decoder: Decoder) throws {
        self.jsonValue = try JSONValue(from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        try jsonValue.encode(to: encoder)
    }

    private static func object(
        type: String,
        fields: [String: JSONValue],
        promptCacheBreakpoint: PromptCacheBreakpoint?
    ) -> JSONValue {
        var object = fields
        object["type"] = .string(type)
        if let promptCacheBreakpoint {
            object["prompt_cache_breakpoint"] = .object([
                "mode": .string(promptCacheBreakpoint.mode),
            ])
        }
        return .object(object)
    }
}

// MARK: - Request Messages

/// A forward-compatible Chat Completions request message boundary.
///
/// This boundary can bridge every legacy `ChatCompletionMessage` and can carry
/// request content parts without expanding the legacy enum's case set.
public struct ChatCompletionRequestMessage: Codable, Sendable, Equatable {
    /// The complete JSON representation of the message.
    public let jsonValue: JSONValue

    /// Creates a dynamic request message.
    public init(jsonValue: JSONValue) {
        self.jsonValue = jsonValue
    }

    /// Bridges any legacy message without changing its wire shape.
    public init(_ message: ChatCompletionMessage) {
        var object: [String: JSONValue]
        switch message {
        case .system(let content, let name):
            object = Self.message(role: "system", content: .string(content), name: name)
        case .user(let content, let name):
            object = Self.message(role: "user", content: .string(content), name: name)
        case .userParts(let parts, let name):
            object = Self.message(
                role: "user",
                content: .array(parts.map { ChatCompletionRequestContentPart($0).jsonValue }),
                name: name
            )
        case .assistant(let content, let name, let refusal, let toolCalls):
            object = ["role": .string("assistant")]
            if let content { object["content"] = .string(content) }
            if let name { object["name"] = .string(name) }
            if let refusal { object["refusal"] = .string(refusal) }
            if let toolCalls {
                object["tool_calls"] = .array(toolCalls.map { call in
                    .object([
                        "id": .string(call.id),
                        "type": .string(call.type),
                        "function": .object([
                            "name": .string(call.function.name),
                            "arguments": .string(call.function.arguments),
                        ]),
                    ])
                })
            }
        case .tool(let content, let toolCallId, let name):
            object = Self.message(role: "tool", content: .string(content), name: name)
            object["tool_call_id"] = .string(toolCallId)
        case .other(let role, let content, let name):
            object = ["role": .string(role)]
            if let content { object["content"] = .string(content) }
            if let name { object["name"] = .string(name) }
        }
        self.init(jsonValue: .object(object))
    }

    /// Creates a user message from request content parts.
    public static func user(
        parts: [ChatCompletionRequestContentPart],
        name: String? = nil
    ) -> Self {
        Self(jsonValue: .object(message(
            role: "user",
            content: .array(parts.map(\.jsonValue)),
            name: name
        )))
    }

    public init(from decoder: Decoder) throws {
        self.jsonValue = try JSONValue(from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        try jsonValue.encode(to: encoder)
    }

    private static func message(
        role: String,
        content: JSONValue,
        name: String?
    ) -> [String: JSONValue] {
        var object: [String: JSONValue] = [
            "role": .string(role),
            "content": content,
        ]
        if let name {
            object["name"] = .string(name)
        }
        return object
    }
}

// MARK: - Request

/// A source-compatible Chat Completions request boundary.
///
/// The request encodes all options at the endpoint's top level. It never nests
/// legacy parameters or prompt-cache options under an SDK-only wrapper key.
public struct ChatCompletionRequest: Encodable, Sendable {
    /// The unrestricted model identifier.
    public let model: String
    /// Messages supplied to the model.
    public let messages: [ChatCompletionRequestMessage]
    /// Prompt-caching options for the request.
    public let promptCacheOptions: PromptCacheOptions?

    private let parameters: ChatCompletionCreateParams?

    /// Creates a focused request containing only model, messages, and cache options.
    public init(
        model: String,
        messages: [ChatCompletionRequestMessage],
        promptCacheOptions: PromptCacheOptions? = nil
    ) {
        self.model = model
        self.messages = messages
        self.promptCacheOptions = promptCacheOptions
        self.parameters = nil
    }

    /// Bridges legacy parameters, optionally replacing their messages.
    ///
    /// All legacy options retain their existing top-level wire keys.
    public init(
        _ parameters: ChatCompletionCreateParams,
        messages: [ChatCompletionRequestMessage]? = nil,
        promptCacheOptions: PromptCacheOptions? = nil
    ) {
        self.model = parameters.model
        self.messages = messages ?? parameters.messages.map(ChatCompletionRequestMessage.init)
        self.promptCacheOptions = promptCacheOptions
        self.parameters = parameters
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try encodeFields(to: &container, streamOverride: nil, overridesStream: false)
    }

    fileprivate func encodeFields(
        to container: inout KeyedEncodingContainer<CodingKeys>,
        streamOverride: Bool?,
        overridesStream: Bool
    ) throws {
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        try container.encodeIfPresent(promptCacheOptions, forKey: .promptCacheOptions)
        guard let parameters else {
            if overridesStream {
                try container.encodeIfPresent(streamOverride, forKey: .stream)
            }
            return
        }
        try container.encodeIfPresent(parameters.temperature, forKey: .temperature)
        try container.encodeIfPresent(parameters.topP, forKey: .topP)
        try container.encodeIfPresent(parameters.n, forKey: .n)
        try container.encodeIfPresent(
            overridesStream ? streamOverride : parameters.stream,
            forKey: .stream
        )
        try container.encodeIfPresent(parameters.stop, forKey: .stop)
        try container.encodeIfPresent(parameters.maxCompletionTokens, forKey: .maxCompletionTokens)
        try container.encodeIfPresent(parameters.presencePenalty, forKey: .presencePenalty)
        try container.encodeIfPresent(parameters.frequencyPenalty, forKey: .frequencyPenalty)
        try container.encodeIfPresent(parameters.logitBias, forKey: .logitBias)
        try container.encodeIfPresent(parameters.logprobs, forKey: .logprobs)
        try container.encodeIfPresent(parameters.topLogprobs, forKey: .topLogprobs)
        try container.encodeIfPresent(parameters.user, forKey: .user)
        try container.encodeIfPresent(parameters.tools, forKey: .tools)
        try container.encodeIfPresent(parameters.toolChoice, forKey: .toolChoice)
        try container.encodeIfPresent(parameters.parallelToolCalls, forKey: .parallelToolCalls)
        try container.encodeIfPresent(parameters.seed, forKey: .seed)
        try container.encodeIfPresent(parameters.responseFormat, forKey: .responseFormat)
        try container.encodeIfPresent(parameters.serviceTier, forKey: .serviceTier)
        try container.encodeIfPresent(parameters.store, forKey: .store)
        try container.encodeIfPresent(parameters.metadata, forKey: .metadata)
        try container.encodeIfPresent(parameters.reasoningEffort, forKey: .reasoningEffort)
        try container.encodeIfPresent(parameters.streamOptions, forKey: .streamOptions)
        try container.encodeIfPresent(parameters.verbosity, forKey: .verbosity)
        try container.encodeIfPresent(parameters.promptCacheKey, forKey: .promptCacheKey)
        try container.encodeIfPresent(parameters.promptCacheRetention, forKey: .promptCacheRetention)
        try container.encodeIfPresent(parameters.safetyIdentifier, forKey: .safetyIdentifier)
        try container.encodeIfPresent(parameters.webSearchOptions, forKey: .webSearchOptions)
        try container.encodeIfPresent(parameters.prediction, forKey: .prediction)
    }

    fileprivate enum CodingKeys: String, CodingKey {
        case model, messages, temperature, topP, n, stream, stop, maxCompletionTokens
        case presencePenalty, frequencyPenalty, logitBias, logprobs, topLogprobs, user
        case tools, toolChoice, parallelToolCalls, seed, responseFormat, serviceTier
        case store, metadata, reasoningEffort, streamOptions, verbosity, promptCacheKey
        case promptCacheOptions, promptCacheRetention, safetyIdentifier, webSearchOptions
        case prediction
    }
}

/// Internal streaming body that forces the endpoint-required `stream: true` key
/// while preserving the request's otherwise flat encoding.
struct ChatCompletionRequestStreamingBody: Encodable, Sendable {
    let request: ChatCompletionRequest

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ChatCompletionRequest.CodingKeys.self)
        try request.encodeFields(to: &container, streamOverride: true, overridesStream: true)
    }
}

/// Internal non-streaming body that omits any bridged `stream` value.
struct ChatCompletionRequestNonStreamingBody: Encodable, Sendable {
    let request: ChatCompletionRequest

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ChatCompletionRequest.CodingKeys.self)
        try request.encodeFields(to: &container, streamOverride: nil, overridesStream: true)
    }
}

private extension ImageDetail {
    var wireValue: String {
        switch self {
        case .auto: return "auto"
        case .low: return "low"
        case .high: return "high"
        case .original: return "original"
        case .other(let value): return value
        }
    }
}
