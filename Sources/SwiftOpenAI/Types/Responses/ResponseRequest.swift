import Foundation

// MARK: - Request Content

/// Detail level for a Responses API file input.
public enum ResponseFileDetail: Codable, Sendable, Equatable, Hashable {
    /// Let the service select the detail level.
    case auto
    /// Use lower-cost rendering.
    case low
    /// Use high-quality rendering.
    case high
    /// A forward-compatible detail value.
    case other(String)

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "auto": self = .auto
        case "low": self = .low
        case "high": self = .high
        default: self = .other(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wireValue)
    }

    fileprivate var wireValue: String {
        switch self {
        case .auto: return "auto"
        case .low: return "low"
        case .high: return "high"
        case .other(let value): return value
        }
    }
}

/// A structured content part for the Responses request boundary.
public struct ResponseRequestContentPart: Codable, Sendable, Equatable {
    /// The complete JSON representation of the content part.
    public let jsonValue: JSONValue

    /// Creates a dynamic content part.
    public init(jsonValue: JSONValue) {
        self.jsonValue = jsonValue
    }

    /// Bridges a legacy Responses content part, defaulting omitted image detail to `.auto`.
    public init(_ contentPart: ResponseInputContentPart) {
        switch contentPart {
        case .inputText(let text):
            self = .inputText(text)
        case .inputImage(let url, let fileId, let detail):
            var fields: [String: JSONValue] = [:]
            if let url { fields["image_url"] = .string(url) }
            if let fileId { fields["file_id"] = .string(fileId) }
            fields["detail"] = .string((detail ?? .auto).responseWireValue)
            self.init(jsonValue: Self.object(type: "input_image", fields: fields, breakpoint: nil))
        }
    }

    /// Creates an input-text content part.
    public static func inputText(
        _ text: String,
        promptCacheBreakpoint: PromptCacheBreakpoint? = nil
    ) -> Self {
        Self(jsonValue: object(
            type: "input_text",
            fields: ["text": .string(text)],
            breakpoint: promptCacheBreakpoint
        ))
    }

    /// Creates an input-image content part from a URL.
    ///
    /// The required image detail defaults to `.auto` and is always encoded.
    public static func inputImage(
        url: String,
        detail: ImageDetail = .auto,
        promptCacheBreakpoint: PromptCacheBreakpoint? = nil
    ) -> Self {
        return Self(jsonValue: object(
            type: "input_image",
            fields: [
                "image_url": .string(url),
                "detail": .string(detail.responseWireValue),
            ],
            breakpoint: promptCacheBreakpoint
        ))
    }

    /// Creates an input-image content part from an uploaded file ID.
    ///
    /// The required image detail defaults to `.auto` and is always encoded.
    public static func inputImage(
        fileID: String,
        detail: ImageDetail = .auto,
        promptCacheBreakpoint: PromptCacheBreakpoint? = nil
    ) -> Self {
        return Self(jsonValue: object(
            type: "input_image",
            fields: [
                "file_id": .string(fileID),
                "detail": .string(detail.responseWireValue),
            ],
            breakpoint: promptCacheBreakpoint
        ))
    }

    /// Creates an input-file content part from an uploaded file ID.
    public static func inputFile(
        id: String,
        detail: ResponseFileDetail? = nil,
        promptCacheBreakpoint: PromptCacheBreakpoint? = nil
    ) -> Self {
        var fields: [String: JSONValue] = ["file_id": .string(id)]
        if let detail { fields["detail"] = .string(detail.wireValue) }
        return Self(jsonValue: object(
            type: "input_file",
            fields: fields,
            breakpoint: promptCacheBreakpoint
        ))
    }

    /// Creates an inline input-file content part.
    ///
    /// The `filename` key is omitted when no filename is supplied.
    public static func inputFile(
        data: String,
        filename: String? = nil,
        detail: ResponseFileDetail? = nil,
        promptCacheBreakpoint: PromptCacheBreakpoint? = nil
    ) -> Self {
        var fields: [String: JSONValue] = ["file_data": .string(data)]
        if let filename { fields["filename"] = .string(filename) }
        if let detail { fields["detail"] = .string(detail.wireValue) }
        return Self(jsonValue: object(
            type: "input_file",
            fields: fields,
            breakpoint: promptCacheBreakpoint
        ))
    }

    /// Creates an input-file content part from a URL.
    public static func inputFile(
        url: String,
        detail: ResponseFileDetail? = nil,
        promptCacheBreakpoint: PromptCacheBreakpoint? = nil
    ) -> Self {
        var fields: [String: JSONValue] = ["file_url": .string(url)]
        if let detail { fields["detail"] = .string(detail.wireValue) }
        return Self(jsonValue: object(
            type: "input_file",
            fields: fields,
            breakpoint: promptCacheBreakpoint
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
        breakpoint: PromptCacheBreakpoint?
    ) -> JSONValue {
        var object = fields
        object["type"] = .string(type)
        if let breakpoint {
            object["prompt_cache_breakpoint"] = .object([
                "mode": .string(breakpoint.mode),
            ])
        }
        return .object(object)
    }
}

/// A forward-compatible message for the Responses request boundary.
public struct ResponseRequestMessage: Codable, Sendable, Equatable {
    /// The complete JSON representation of the message.
    public let jsonValue: JSONValue

    /// Creates a dynamic request message.
    public init(jsonValue: JSONValue) {
        self.jsonValue = jsonValue
    }

    /// Creates a message with plain text content.
    public init(role: String, content: String) {
        self.jsonValue = .object([
            "type": .string("message"),
            "role": .string(role),
            "content": .string(content),
        ])
    }

    /// Creates a message with typed request content parts.
    public init(role: String, parts: [ResponseRequestContentPart]) {
        self.jsonValue = .object([
            "type": .string("message"),
            "role": .string(role),
            "content": .array(parts.map(\.jsonValue)),
        ])
    }

    /// Bridges a legacy input message.
    public init(_ message: ResponseInputMessage) {
        switch message.content {
        case .text(let text):
            self.init(role: message.role, content: text)
        case .parts(let parts):
            self.init(role: message.role, parts: parts.map(ResponseRequestContentPart.init))
        }
    }

    /// Creates a user message with request content parts.
    public static func user(parts: [ResponseRequestContentPart]) -> Self {
        Self(role: "user", parts: parts)
    }

    public init(from decoder: Decoder) throws {
        self.jsonValue = try JSONValue(from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        try jsonValue.encode(to: encoder)
    }
}

// MARK: - Reasoning and Compaction Items

/// A reasoning-text block that can be fed back on a later turn.
public struct ResponseReasoningContent: Codable, Sendable, Equatable {
    /// The fixed block discriminator, always `"reasoning_text"`.
    public var type: String { "reasoning_text" }
    /// The reasoning text.
    public let text: String

    /// Creates a reasoning-text block.
    public init(text: String) {
        self.text = text
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case text
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        guard type == "reasoning_text" else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Expected ResponseReasoningContent type \"reasoning_text\", but found \"\(type)\"."
            )
        }
        self.text = try container.decode(String.self, forKey: .text)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("reasoning_text", forKey: .type)
        try container.encode(text, forKey: .text)
    }
}

/// A required summary-text block for a reasoning request input item.
///
/// Its `type` discriminator is fixed to `"summary_text"`; callers provide only `text`.
public struct ResponseReasoningSummaryContent: Codable, Sendable, Equatable {
    /// The fixed block discriminator, always `"summary_text"`.
    public var type: String { "summary_text" }
    /// The required reasoning summary text.
    public let text: String

    /// Creates a summary-text block for a reasoning request.
    public init(text: String) {
        self.text = text
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case text
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        guard type == "summary_text" else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Expected ResponseReasoningSummaryContent type \"summary_text\", but found \"\(type)\"."
            )
        }
        self.text = try container.decode(String.self, forKey: .text)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("summary_text", forKey: .type)
        try container.encode(text, forKey: .text)
    }
}

/// A reasoning input item for manually managed conversation state.
public struct ResponseReasoningInputItem: Codable, Sendable, Equatable {
    /// The fixed item discriminator, always `"reasoning"`.
    public var type: String { "reasoning" }
    /// The reasoning item identifier.
    public let id: String
    /// Reasoning summary blocks.
    public let summary: [ResponseReasoningSummaryContent]
    /// Optional reasoning-text blocks.
    public let content: [ResponseReasoningContent]?
    /// Optional encrypted reasoning state.
    public let encryptedContent: String?
    /// Optional item status echoed by the service.
    public let status: String?

    /// Creates a reasoning input item.
    public init(
        id: String,
        summary: [ResponseReasoningSummaryContent],
        content: [ResponseReasoningContent]? = nil,
        encryptedContent: String? = nil,
        status: String? = nil
    ) {
        self.id = id
        self.summary = summary
        self.content = content
        self.encryptedContent = encryptedContent
        self.status = status
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case summary
        case content
        case encryptedContent
        case status
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        guard type == "reasoning" else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Expected ResponseReasoningInputItem type \"reasoning\", but found \"\(type)\"."
            )
        }
        self.id = try container.decode(String.self, forKey: .id)
        self.summary = try container.decode([ResponseReasoningSummaryContent].self, forKey: .summary)
        self.content = try container.decodeIfPresent([ResponseReasoningContent].self, forKey: .content)
        self.encryptedContent = try container.decodeIfPresent(String.self, forKey: .encryptedContent)
        self.status = try container.decodeIfPresent(String.self, forKey: .status)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("reasoning", forKey: .type)
        try container.encode(id, forKey: .id)
        try container.encode(summary, forKey: .summary)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(encryptedContent, forKey: .encryptedContent)
        try container.encodeIfPresent(status, forKey: .status)
    }
}

/// A compaction input item that can be fed back to Responses endpoints.
public struct ResponseCompactionInputItem: Codable, Sendable, Equatable {
    /// The fixed item discriminator, always `"compaction"`.
    public var type: String { "compaction" }
    /// The encrypted compacted context.
    public let encryptedContent: String
    /// Optional compaction item identifier.
    public let id: String?

    /// Creates a compaction input item.
    public init(encryptedContent: String, id: String? = nil) {
        self.encryptedContent = encryptedContent
        self.id = id
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case encryptedContent
        case id
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        guard type == "compaction" else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Expected ResponseCompactionInputItem type \"compaction\", but found \"\(type)\"."
            )
        }
        self.encryptedContent = try container.decode(String.self, forKey: .encryptedContent)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("compaction", forKey: .type)
        try container.encode(encryptedContent, forKey: .encryptedContent)
        try container.encodeIfPresent(id, forKey: .id)
    }
}

/// A structured input item for the Responses request boundary.
public struct ResponseRequestInputItem: Codable, Sendable, Equatable {
    /// The complete JSON representation of the input item.
    public let jsonValue: JSONValue

    /// Creates a dynamic input item.
    public init(jsonValue: JSONValue) {
        self.jsonValue = jsonValue
    }

    /// Creates a message input item.
    public init(message: ResponseRequestMessage) {
        self.jsonValue = message.jsonValue
    }

    /// Creates a reasoning input item.
    public init(reasoning: ResponseReasoningInputItem) {
        var object: [String: JSONValue] = [
            "type": .string(reasoning.type),
            "id": .string(reasoning.id),
            "summary": .array(reasoning.summary.map { summary in
                .object(["type": .string(summary.type), "text": .string(summary.text)])
            }),
        ]
        if let content = reasoning.content {
            object["content"] = .array(content.map {
                .object(["type": .string($0.type), "text": .string($0.text)])
            })
        }
        if let encryptedContent = reasoning.encryptedContent {
            object["encrypted_content"] = .string(encryptedContent)
        }
        if let status = reasoning.status {
            object["status"] = .string(status)
        }
        self.jsonValue = .object(object)
    }

    /// Creates a compaction input item.
    public init(compaction: ResponseCompactionInputItem) {
        var object: [String: JSONValue] = [
            "type": .string(compaction.type),
            "encrypted_content": .string(compaction.encryptedContent),
        ]
        if let id = compaction.id { object["id"] = .string(id) }
        self.jsonValue = .object(object)
    }

    /// Bridges a legacy input item.
    ///
    /// Legacy input images with omitted detail are normalized to `"auto"`.
    public init(_ item: ResponseInputItem) {
        switch item {
        case .message(let message):
            self.init(message: ResponseRequestMessage(message))
        case .functionCallOutput(let output):
            self.init(jsonValue: .object([
                "type": .string(output.type),
                "call_id": .string(output.callId),
                "output": .string(output.output),
            ]))
        case .functionCall(let call):
            self.init(jsonValue: .object([
                "type": .string(call.type),
                "call_id": .string(call.callId),
                "name": .string(call.name),
                "arguments": .string(call.arguments),
            ]))
        case .itemReference(let reference):
            self.init(jsonValue: .object([
                "type": .string(reference.type),
                "id": .string(reference.id),
            ]))
        }
    }

    public init(from decoder: Decoder) throws {
        self.jsonValue = try JSONValue(from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        try jsonValue.encode(to: encoder)
    }
}

/// A source-compatible Responses input boundary.
public struct ResponseRequestInput: Codable, Sendable, Equatable {
    /// The complete JSON representation of the input.
    public let jsonValue: JSONValue

    /// Creates a dynamic request input.
    public init(jsonValue: JSONValue) {
        self.jsonValue = jsonValue
    }

    /// Creates a plain text input.
    public static func text(_ text: String) -> Self {
        Self(jsonValue: .string(text))
    }

    /// Creates an input from request messages.
    public static func messages(_ messages: [ResponseRequestMessage]) -> Self {
        Self(jsonValue: .array(messages.map(\.jsonValue)))
    }

    /// Creates an input from request items.
    public static func items(_ items: [ResponseRequestInputItem]) -> Self {
        Self(jsonValue: .array(items.map(\.jsonValue)))
    }

    /// Bridges a legacy Responses input.
    public init(_ input: ResponseInput) {
        switch input {
        case .text(let text):
            self = .text(text)
        case .messages(let messages):
            self = .messages(messages.map(ResponseRequestMessage.init))
        case .items(let items):
            self = .items(items.map(ResponseRequestInputItem.init))
        }
    }

    public init(from decoder: Decoder) throws {
        self.jsonValue = try JSONValue(from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        try jsonValue.encode(to: encoder)
    }
}

// MARK: - Create Request

/// Optional top-level settings for a Responses create request.
public struct ResponseCreateOptions: Sendable {
    /// Optional system instructions.
    public let instructions: String?
    /// Maximum number of output tokens.
    public let maxOutputTokens: Int?
    /// Sampling temperature.
    public let temperature: Double?
    /// Nucleus sampling parameter.
    public let topP: Double?
    /// Whether to store the response.
    public let store: Bool?
    /// Metadata attached to the response.
    public let metadata: [String: String]?
    /// Previous response identifier.
    public let previousResponseId: String?
    /// Conversation identifier.
    public let conversation: String?
    /// Tools available to the model.
    public let tools: [ResponseTool]?
    /// Tool selection policy.
    public let toolChoice: ResponseToolChoice?
    /// Text output configuration.
    public let text: ResponseTextConfig?
    /// Truncation strategy.
    public let truncation: TruncationStrategy?
    /// Context management configuration.
    public let contextManagement: [ContextManagement]?
    /// Reasoning configuration.
    public let reasoning: ReasoningConfig?
    /// Whether tool calls may run in parallel.
    public let parallelToolCalls: Bool?
    /// Maximum number of tool calls.
    public let maxToolCalls: Int?
    /// Requested service tier.
    public let serviceTier: ServiceTier?
    /// Prompt-cache routing key.
    public let promptCacheKey: String?
    /// Prompt-caching options.
    public let promptCacheOptions: PromptCacheOptions?
    /// Deprecated prompt-cache retention policy, independent of cache options.
    public let promptCacheRetention: PromptCacheRetention?

    /// Creates Responses create options.
    public init(
        instructions: String? = nil,
        maxOutputTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        store: Bool? = nil,
        metadata: [String: String]? = nil,
        previousResponseId: String? = nil,
        conversation: String? = nil,
        tools: [ResponseTool]? = nil,
        toolChoice: ResponseToolChoice? = nil,
        text: ResponseTextConfig? = nil,
        truncation: TruncationStrategy? = nil,
        contextManagement: [ContextManagement]? = nil,
        reasoning: ReasoningConfig? = nil,
        parallelToolCalls: Bool? = nil,
        maxToolCalls: Int? = nil,
        serviceTier: ServiceTier? = nil,
        promptCacheKey: String? = nil,
        promptCacheOptions: PromptCacheOptions? = nil,
        promptCacheRetention: PromptCacheRetention? = nil
    ) {
        self.instructions = instructions
        self.maxOutputTokens = maxOutputTokens
        self.temperature = temperature
        self.topP = topP
        self.store = store
        self.metadata = metadata
        self.previousResponseId = previousResponseId
        self.conversation = conversation
        self.tools = tools
        self.toolChoice = toolChoice
        self.text = text
        self.truncation = truncation
        self.contextManagement = contextManagement
        self.reasoning = reasoning
        self.parallelToolCalls = parallelToolCalls
        self.maxToolCalls = maxToolCalls
        self.serviceTier = serviceTier
        self.promptCacheKey = promptCacheKey
        self.promptCacheOptions = promptCacheOptions
        self.promptCacheRetention = promptCacheRetention
    }
}

/// A Responses create request whose options encode flat at the endpoint top level.
public struct ResponseCreateRequest: Encodable, Sendable {
    /// The unrestricted model identifier.
    public let model: String
    /// The modern request input, created directly or with `.text`, `.messages`, or `.items`.
    public let input: ResponseRequestInput
    /// Optional top-level create settings.
    public let options: ResponseCreateOptions

    /// Creates a Responses request using the modern request-input boundary.
    ///
    /// The `input:` shorthand forms `.text`, `.messages`, and `.items` resolve to
    /// `ResponseRequestInput`.
    ///
    /// - Parameters:
    ///   - model: The unrestricted model identifier.
    ///   - input: The modern Responses request input.
    ///   - options: Optional top-level create settings.
    public init(
        model: String,
        input: ResponseRequestInput,
        options: ResponseCreateOptions = .init()
    ) {
        self.model = model
        self.input = input
        self.options = options
    }

    /// Creates a Responses request by explicitly bridging a legacy `ResponseInput`.
    ///
    /// Use `legacyInput:` only for legacy values. The value is converted through
    /// `ResponseRequestInput`; legacy input images with omitted detail are normalized
    /// to `"auto"`.
    ///
    /// - Parameters:
    ///   - model: The unrestricted model identifier.
    ///   - legacyInput: The legacy Responses input to bridge.
    ///   - options: Optional top-level create settings.
    public init(
        model: String,
        legacyInput: ResponseInput,
        options: ResponseCreateOptions = .init()
    ) {
        self.init(
            model: model,
            input: ResponseRequestInput(legacyInput),
            options: options
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ResponseRequestCodingKeys.self)
        try encodeFields(to: &container, stream: nil)
    }

    fileprivate func encodeFields(
        to container: inout KeyedEncodingContainer<ResponseRequestCodingKeys>,
        stream: Bool?
    ) throws {
        try container.encode(model, forKey: .model)
        try container.encode(input, forKey: .input)
        try container.encodeIfPresent(options.instructions, forKey: .instructions)
        try container.encodeIfPresent(options.maxOutputTokens, forKey: .maxOutputTokens)
        try container.encodeIfPresent(options.temperature, forKey: .temperature)
        try container.encodeIfPresent(options.topP, forKey: .topP)
        try container.encodeIfPresent(stream, forKey: .stream)
        try container.encodeIfPresent(options.store, forKey: .store)
        try container.encodeIfPresent(options.metadata, forKey: .metadata)
        try container.encodeIfPresent(options.previousResponseId, forKey: .previousResponseId)
        try container.encodeIfPresent(options.conversation, forKey: .conversation)
        try container.encodeIfPresent(options.tools, forKey: .tools)
        try container.encodeIfPresent(options.toolChoice, forKey: .toolChoice)
        try container.encodeIfPresent(options.text, forKey: .text)
        try container.encodeIfPresent(options.truncation, forKey: .truncation)
        try container.encodeIfPresent(options.contextManagement, forKey: .contextManagement)
        try container.encodeIfPresent(options.reasoning, forKey: .reasoning)
        try container.encodeIfPresent(options.parallelToolCalls, forKey: .parallelToolCalls)
        try container.encodeIfPresent(options.maxToolCalls, forKey: .maxToolCalls)
        try container.encodeIfPresent(options.serviceTier, forKey: .serviceTier)
        try container.encodeIfPresent(options.promptCacheKey, forKey: .promptCacheKey)
        try container.encodeIfPresent(options.promptCacheOptions, forKey: .promptCacheOptions)
        try container.encodeIfPresent(options.promptCacheRetention, forKey: .promptCacheRetention)
    }
}

/// Parameters for the Responses compact endpoint.
///
/// Reasoning configuration is intentionally absent because compact does not accept it.
public struct ResponseCompactRequest: Encodable, Sendable {
    /// The unrestricted model identifier.
    public let model: String
    /// Optional input to compact.
    public let input: ResponseRequestInput?
    /// Optional system instructions.
    public let instructions: String?
    /// Optional previous response identifier.
    public let previousResponseId: String?
    /// Optional prompt-cache routing key.
    public let promptCacheKey: String?
    /// Optional prompt-caching configuration.
    public let promptCacheOptions: PromptCacheOptions?
    /// Deprecated prompt-cache retention policy.
    public let promptCacheRetention: PromptCacheRetention?
    /// Optional service tier.
    public let serviceTier: ServiceTier?

    /// Creates a compact request.
    public init(
        model: String,
        input: ResponseRequestInput? = nil,
        instructions: String? = nil,
        previousResponseId: String? = nil,
        promptCacheKey: String? = nil,
        promptCacheOptions: PromptCacheOptions? = nil,
        promptCacheRetention: PromptCacheRetention? = nil,
        serviceTier: ServiceTier? = nil
    ) {
        self.model = model
        self.input = input
        self.instructions = instructions
        self.previousResponseId = previousResponseId
        self.promptCacheKey = promptCacheKey
        self.promptCacheOptions = promptCacheOptions
        self.promptCacheRetention = promptCacheRetention
        self.serviceTier = serviceTier
    }
}

enum ResponseRequestCodingKeys: String, CodingKey {
    case type, model, input, instructions, maxOutputTokens, temperature, topP, stream
    case store, metadata, previousResponseId, conversation, tools, toolChoice, text
    case truncation, contextManagement, reasoning, parallelToolCalls, maxToolCalls
    case serviceTier, promptCacheKey, promptCacheOptions, promptCacheRetention
}

/// Internal SSE body that adds `stream: true` without nesting the request options.
struct ResponseCreateRequestStreamingBody: Encodable, Sendable {
    let request: ResponseCreateRequest

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ResponseRequestCodingKeys.self)
        try request.encodeFields(to: &container, stream: true)
    }
}

/// Internal WebSocket envelope for an exact flat `response.create` event.
struct ResponseWebSocketCreateRequest: Encodable, Sendable {
    let request: ResponseCreateRequest

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ResponseRequestCodingKeys.self)
        try container.encode("response.create", forKey: .type)
        try request.encodeFields(to: &container, stream: nil)
    }
}

private extension ImageDetail {
    var responseWireValue: String {
        switch self {
        case .auto: return "auto"
        case .low: return "low"
        case .high: return "high"
        case .original: return "original"
        case .other(let value): return value
        }
    }
}
