import Foundation

// MARK: - WebSocket Client Event

/// Event sent by the client over a WebSocket connection to create a response.
///
/// The payload mirrors the Responses API create body, with the addition of `generate`
/// for warmup requests. Transport-specific fields like `stream` and `background` are
/// not used in WebSocket mode.
///
/// Usage:
/// ```swift
/// let event = ResponsesClientEvent(
///     model: "gpt-5.2",
///     input: .text("Hello"),
///     store: false
/// )
/// ```
public struct ResponsesClientEvent: Encodable, Sendable {
    /// Always `"response.create"`.
    public let type: String = "response.create"

    /// The model to use.
    public let model: String

    /// The input for this turn.
    public let input: ResponseInput

    /// System instructions.
    public let instructions: String?

    /// Maximum number of output tokens.
    public let maxOutputTokens: Int?

    /// Sampling temperature.
    public let temperature: Double?

    /// Nucleus sampling parameter.
    public let topP: Double?

    /// Whether to store the response for later retrieval.
    public let store: Bool?

    /// Optional metadata.
    public let metadata: [String: String]?

    /// ID of a previous response to continue from.
    public let previousResponseId: String?

    /// Tools available to the model.
    public let tools: [ResponseTool]?

    /// How the model should select tools.
    public let toolChoice: ResponseToolChoice?

    /// Text output configuration (structured outputs).
    public let text: ResponseTextConfig?

    /// Truncation strategy.
    public let truncation: String?

    /// Context management configuration.
    public let contextManagement: [ContextManagement]?

    /// Reasoning configuration.
    public let reasoning: ReasoningConfig?

    /// Whether to run tool calls in parallel.
    public let parallelToolCalls: Bool?

    /// Maximum number of tool calls per turn.
    public let maxToolCalls: Int?

    /// Service tier.
    public let serviceTier: String?

    /// Set to `false` to warm up request state without generating output.
    /// The warmup returns a response ID usable as `previousResponseId` on the next turn.
    public let generate: Bool?

    public init(
        model: String,
        input: ResponseInput,
        instructions: String? = nil,
        maxOutputTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        store: Bool? = nil,
        metadata: [String: String]? = nil,
        previousResponseId: String? = nil,
        tools: [ResponseTool]? = nil,
        toolChoice: ResponseToolChoice? = nil,
        text: ResponseTextConfig? = nil,
        truncation: String? = nil,
        contextManagement: [ContextManagement]? = nil,
        reasoning: ReasoningConfig? = nil,
        parallelToolCalls: Bool? = nil,
        maxToolCalls: Int? = nil,
        serviceTier: String? = nil,
        generate: Bool? = nil
    ) {
        self.model = model
        self.input = input
        self.instructions = instructions
        self.maxOutputTokens = maxOutputTokens
        self.temperature = temperature
        self.topP = topP
        self.store = store
        self.metadata = metadata
        self.previousResponseId = previousResponseId
        self.tools = tools
        self.toolChoice = toolChoice
        self.text = text
        self.truncation = truncation
        self.contextManagement = contextManagement
        self.reasoning = reasoning
        self.parallelToolCalls = parallelToolCalls
        self.maxToolCalls = maxToolCalls
        self.serviceTier = serviceTier
        self.generate = generate
    }
}

// MARK: - WebSocket Error Event

/// Error event received from the server over a WebSocket connection.
public struct WebSocketErrorEvent: Codable, Sendable {
    /// Always `"error"`.
    public let type: String
    /// HTTP-like status code.
    public let status: Int?
    /// Error details.
    public let error: WebSocketErrorDetail
}

/// Details of a WebSocket error.
public struct WebSocketErrorDetail: Codable, Sendable {
    /// Error type (e.g. `"invalid_request_error"`).
    public let type: String?
    /// Machine-readable error code (e.g. `"previous_response_not_found"`, `"websocket_connection_limit_reached"`).
    public let code: String?
    /// Human-readable error message.
    public let message: String
    /// The parameter that caused the error, if applicable.
    public let param: String?
}

// MARK: - WebSocket Connection State

/// The state of a WebSocket connection.
public enum WebSocketConnectionState: Sendable {
    /// Not yet connected.
    case disconnected
    /// Connection is being established.
    case connecting
    /// Connected and ready to send/receive.
    case connected
    /// Connection is closing.
    case closing
}
