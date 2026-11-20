import Foundation

/// Shared evidence for a Decisions request: plain text or ordered conversation items.
public struct DecisionInput: Codable, Sendable, Equatable {
    /// The complete wire representation, including any caller-supplied fields.
    public let jsonValue: JSONValue

    /// Creates input from a caller-supplied wire representation.
    public init(jsonValue: JSONValue) {
        self.jsonValue = jsonValue
    }

    /// Creates plain-text evidence shared by all questions.
    public static func text(_ text: String) -> Self {
        Self(jsonValue: .string(text))
    }

    /// Creates evidence from messages, tool calls, and matching tool outputs in order.
    public static func items(_ items: [DecisionInputItem]) -> Self {
        Self(jsonValue: .array(items.map(\.jsonValue)))
    }

    /// Decodes the complete input representation.
    public init(from decoder: Decoder) throws {
        self.jsonValue = try JSONValue(from: decoder)
    }

    /// Encodes the input without changing caller-supplied JSON keys.
    public func encode(to encoder: Encoder) throws {
        try jsonValue.encode(to: encoder)
    }
}

/// A shared input-text part, also supported in system and developer messages.
public struct DecisionInputText: Codable, Sendable, Equatable {
    /// The complete JSON representation of the text part.
    public let jsonValue: JSONValue

    /// Creates a text part with optional explicit prompt caching.
    public init(_ text: String, promptCacheBreakpoint: PromptCacheBreakpoint? = nil) {
        self.jsonValue = decisionPart("input_text", fields: ["text": .string(text)], breakpoint: promptCacheBreakpoint)
    }

    /// Creates a text part from a caller-supplied wire representation.
    public init(jsonValue: JSONValue) {
        self.jsonValue = jsonValue
    }

    /// Decodes the complete text-part representation.
    public init(from decoder: Decoder) throws {
        self.jsonValue = try JSONValue(from: decoder)
    }

    /// Encodes the complete text-part representation.
    public func encode(to encoder: Encoder) throws {
        try jsonValue.encode(to: encoder)
    }
}

/// A text, image, or JSON part in a shared user message.
public struct DecisionInputPart: Codable, Sendable, Equatable {
    /// The complete JSON representation of the content part.
    public let jsonValue: JSONValue

    /// Creates a content part from a caller-supplied wire representation.
    public init(jsonValue: JSONValue) {
        self.jsonValue = jsonValue
    }

    /// Creates shared text evidence with an optional cache breakpoint.
    public static func text(_ text: String, promptCacheBreakpoint: PromptCacheBreakpoint? = nil) -> Self {
        Self(jsonValue: DecisionInputText(text, promptCacheBreakpoint: promptCacheBreakpoint).jsonValue)
    }

    /// Creates image evidence from a public HTTP(S) URL or a base64 data URL.
    ///
    /// File IDs are not supported. Omitting detail lets the service select `auto`.
    public static func image(
        url: String,
        detail: ImageDetail? = nil,
        promptCacheBreakpoint: PromptCacheBreakpoint? = nil
    ) -> Self {
        Self(jsonValue: decisionImage(url: url, detail: detail, breakpoint: promptCacheBreakpoint))
    }

    /// Creates structured evidence from a JSON object or an array of objects.
    ///
    /// Nested values may be any JSON value. Service size and depth limits apply.
    public static func json(_ data: JSONValue) -> Self {
        Self(jsonValue: decisionPart("input_json", fields: ["data": data]))
    }

    /// Decodes the complete content-part representation.
    public init(from decoder: Decoder) throws {
        self.jsonValue = try JSONValue(from: decoder)
    }

    /// Encodes the complete content-part representation.
    public func encode(to encoder: Encoder) throws {
        try jsonValue.encode(to: encoder)
    }
}

/// Question-specific text, image, or JSON content, without prompt-cache breakpoints.
public struct DecisionQuestionInputPart: Codable, Sendable, Equatable {
    /// The complete JSON representation of the question content.
    public let jsonValue: JSONValue

    /// Creates question content from a caller-supplied wire representation.
    public init(jsonValue: JSONValue) {
        self.jsonValue = jsonValue
    }

    /// Creates question-specific text instructions.
    public static func text(_ text: String) -> Self {
        Self(jsonValue: decisionPart("input_text", fields: ["text": .string(text)]))
    }

    /// Creates a question-specific image from a public HTTP(S) URL or base64 data URL.
    public static func image(url: String, detail: ImageDetail? = nil) -> Self {
        Self(jsonValue: decisionImage(url: url, detail: detail))
    }

    /// Creates question-specific JSON from an object or an array of objects.
    public static func json(_ data: JSONValue) -> Self {
        Self(jsonValue: decisionPart("input_json", fields: ["data": data]))
    }

    /// Decodes the complete question-content representation.
    public init(from decoder: Decoder) throws {
        self.jsonValue = try JSONValue(from: decoder)
    }

    /// Encodes the complete question-content representation.
    public func encode(to encoder: Encoder) throws {
        try jsonValue.encode(to: encoder)
    }
}

/// Text or image evidence returned by a function or custom tool.
public struct DecisionToolOutputPart: Codable, Sendable, Equatable {
    /// The complete JSON representation of the tool-output part.
    public let jsonValue: JSONValue

    /// Creates a tool-output part from a caller-supplied wire representation.
    public init(jsonValue: JSONValue) {
        self.jsonValue = jsonValue
    }

    /// Creates tool-output text with an optional cache breakpoint.
    public static func text(_ text: String, promptCacheBreakpoint: PromptCacheBreakpoint? = nil) -> Self {
        Self(jsonValue: DecisionInputPart.text(text, promptCacheBreakpoint: promptCacheBreakpoint).jsonValue)
    }

    /// Creates a tool-output image from a public HTTP(S) URL or base64 data URL.
    public static func image(
        url: String,
        detail: ImageDetail? = nil,
        promptCacheBreakpoint: PromptCacheBreakpoint? = nil
    ) -> Self {
        Self(jsonValue: decisionImage(url: url, detail: detail, breakpoint: promptCacheBreakpoint))
    }

    /// Decodes the complete tool-output-part representation.
    public init(from decoder: Decoder) throws {
        self.jsonValue = try JSONValue(from: decoder)
    }

    /// Encodes the complete tool-output-part representation.
    public func encode(to encoder: Encoder) throws {
        try jsonValue.encode(to: encoder)
    }
}

/// Output text or a refusal in an assistant history message.
public struct DecisionAssistantContentPart: Codable, Sendable, Equatable {
    /// The complete JSON representation of the assistant content.
    public let jsonValue: JSONValue

    /// Creates assistant content from a caller-supplied wire representation.
    public init(jsonValue: JSONValue) {
        self.jsonValue = jsonValue
    }

    /// Creates assistant output text.
    public static func text(_ text: String) -> Self {
        Self(jsonValue: decisionPart("output_text", fields: ["text": .string(text)]))
    }

    /// Creates an assistant refusal.
    public static func refusal(_ refusal: String) -> Self {
        Self(jsonValue: decisionPart("refusal", fields: ["refusal": .string(refusal)]))
    }

    /// Decodes the complete assistant-content representation.
    public init(from decoder: Decoder) throws {
        self.jsonValue = try JSONValue(from: decoder)
    }

    /// Encodes the complete assistant-content representation.
    public func encode(to encoder: Encoder) throws {
        try jsonValue.encode(to: encoder)
    }
}

/// A message, function call, custom tool call, or tool output in Decisions evidence.
public struct DecisionInputItem: Codable, Sendable, Equatable {
    /// The complete JSON representation of the history item.
    public let jsonValue: JSONValue

    /// Creates a history item from a caller-supplied wire representation.
    public init(jsonValue: JSONValue) {
        self.jsonValue = jsonValue
    }

    /// Creates a plain-text user message.
    public static func user(_ text: String) -> Self {
        message(role: "user", content: .string(text))
    }

    /// Creates a user message containing shared text, image, or JSON evidence.
    public static func user(parts: [DecisionInputPart]) -> Self {
        message(role: "user", content: .array(parts.map(\.jsonValue)))
    }

    /// Creates a plain-text developer message.
    public static func developer(_ text: String) -> Self {
        message(role: "developer", content: .string(text))
    }

    /// Creates a developer message containing only input-text parts.
    public static func developer(parts: [DecisionInputText]) -> Self {
        message(role: "developer", content: .array(parts.map(\.jsonValue)))
    }

    /// Creates a plain-text system message.
    public static func system(_ text: String) -> Self {
        message(role: "system", content: .string(text))
    }

    /// Creates a system message containing only input-text parts.
    public static func system(parts: [DecisionInputText]) -> Self {
        message(role: "system", content: .array(parts.map(\.jsonValue)))
    }

    /// Creates a plain-text assistant message with an optional `commentary` or `final_answer` phase.
    public static func assistant(_ text: String, phase: String? = nil) -> Self {
        message(role: "assistant", content: .string(text), phase: phase)
    }

    /// Creates an assistant message containing output-text and refusal parts.
    public static func assistant(parts: [DecisionAssistantContentPart], phase: String? = nil) -> Self {
        message(role: "assistant", content: .array(parts.map(\.jsonValue)), phase: phase)
    }

    /// Creates a function call; its arguments are a JSON-encoded string.
    public static func functionCall(
        callID: String,
        name: String,
        arguments: String,
        id: String? = nil,
        namespace: String? = nil,
        status: String? = nil
    ) -> Self {
        toolCall(type: "function_call", callID: callID, name: name, payloadKey: "arguments",
                 payload: arguments, id: id, namespace: namespace, status: status)
    }

    /// Creates a text result associated with a matching function call ID.
    public static func functionCallOutput(callID: String, output: String, id: String? = nil, status: String? = nil) -> Self {
        toolOutput(type: "function_call_output", callID: callID, output: .string(output), id: id, status: status)
    }

    /// Creates a text-and-image result associated with a matching function call ID.
    public static func functionCallOutput(
        callID: String,
        parts: [DecisionToolOutputPart],
        id: String? = nil,
        status: String? = nil
    ) -> Self {
        toolOutput(type: "function_call_output", callID: callID, output: .array(parts.map(\.jsonValue)), id: id, status: status)
    }

    /// Creates a custom tool call with free-form input.
    public static func customToolCall(
        callID: String,
        name: String,
        input: String,
        id: String? = nil,
        namespace: String? = nil,
        status: String? = nil
    ) -> Self {
        toolCall(type: "custom_tool_call", callID: callID, name: name, payloadKey: "input",
                 payload: input, id: id, namespace: namespace, status: status)
    }

    /// Creates a text result associated with a matching custom tool call ID.
    public static func customToolCallOutput(callID: String, output: String, id: String? = nil, status: String? = nil) -> Self {
        toolOutput(type: "custom_tool_call_output", callID: callID, output: .string(output), id: id, status: status)
    }

    /// Creates a text-and-image result associated with a matching custom tool call ID.
    public static func customToolCallOutput(
        callID: String,
        parts: [DecisionToolOutputPart],
        id: String? = nil,
        status: String? = nil
    ) -> Self {
        toolOutput(type: "custom_tool_call_output", callID: callID, output: .array(parts.map(\.jsonValue)), id: id, status: status)
    }

    /// Decodes the complete history-item representation.
    public init(from decoder: Decoder) throws {
        self.jsonValue = try JSONValue(from: decoder)
    }

    /// Encodes the complete history-item representation.
    public func encode(to encoder: Encoder) throws {
        try jsonValue.encode(to: encoder)
    }

    private static func message(role: String, content: JSONValue, phase: String? = nil) -> Self {
        var fields: [String: JSONValue] = ["role": .string(role), "content": content]
        if let phase { fields["phase"] = .string(phase) }
        return Self(jsonValue: decisionPart("message", fields: fields))
    }

    private static func toolCall(
        type: String, callID: String, name: String, payloadKey: String, payload: String,
        id: String?, namespace: String?, status: String?
    ) -> Self {
        var fields: [String: JSONValue] = ["call_id": .string(callID), "name": .string(name), payloadKey: .string(payload)]
        if let id { fields["id"] = .string(id) }
        if let namespace { fields["namespace"] = .string(namespace) }
        if let status { fields["status"] = .string(status) }
        return Self(jsonValue: decisionPart(type, fields: fields))
    }

    private static func toolOutput(type: String, callID: String, output: JSONValue, id: String?, status: String?) -> Self {
        var fields: [String: JSONValue] = ["call_id": .string(callID), "output": output]
        if let id { fields["id"] = .string(id) }
        if let status { fields["status"] = .string(status) }
        return Self(jsonValue: decisionPart(type, fields: fields))
    }
}

private func decisionPart(_ type: String, fields: [String: JSONValue], breakpoint: PromptCacheBreakpoint? = nil) -> JSONValue {
    var object = fields
    object["type"] = .string(type)
    if let breakpoint {
        object["prompt_cache_breakpoint"] = .object(["mode": .string(breakpoint.mode)])
    }
    return .object(object)
}

private func decisionImage(url: String, detail: ImageDetail?, breakpoint: PromptCacheBreakpoint? = nil) -> JSONValue {
    var fields: [String: JSONValue] = ["image_url": .string(url)]
    if let detail {
        let value: String
        switch detail {
        case .auto: value = "auto"
        case .low: value = "low"
        case .high: value = "high"
        case .original: value = "original"
        case .other(let other): value = other
        }
        fields["detail"] = .string(value)
    }
    return decisionPart("input_image", fields: fields, breakpoint: breakpoint)
}
