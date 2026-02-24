import Foundation

#if canImport(Darwin)

/// A persistent WebSocket connection to the Responses API for low-latency
/// multi-turn workflows.
///
/// WebSocket mode keeps a connection open to `/v1/responses` and sends only
/// incremental input per turn, reducing per-turn overhead. Ideal for agentic
/// workflows with many tool-call round trips (up to ~40% faster end-to-end).
///
/// Usage:
/// ```swift
/// let ws = client.responses.connectWebSocket()
/// await ws.connect()
///
/// // First turn
/// let stream1 = try await ws.create(
///     model: "gpt-5.2",
///     input: .text("Find the bug in this code."),
///     tools: [codeTool],
///     store: false
/// )
/// var responseId: String?
/// for try await event in stream1 {
///     if event.type == "response.completed", let id = event.response?.id {
///         responseId = id
///     }
///     if let delta = event.delta { print(delta, terminator: "") }
/// }
///
/// // Continue with tool output on the same connection
/// let stream2 = try await ws.create(
///     model: "gpt-5.2",
///     input: .items([
///         .functionCallOutput(FunctionCallOutput(callId: "call_123", output: "result"))
///     ]),
///     previousResponseId: responseId,
///     tools: [codeTool],
///     store: false
/// )
/// for try await event in stream2 { ... }
///
/// await ws.close()
/// ```
///
/// - Note: WebSocket connections are limited to 60 minutes. Reconnect when the limit is reached.
/// - Note: Only one response can be in-flight at a time per connection (sequential execution).
public actor ResponsesWebSocket {

    private let client: WebSocketClient
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var isInFlight = false

    init(configuration: Configuration, session: URLSession) {
        var request = URLRequest(url: configuration.websocketBaseURL.appendingPathComponent("responses"))
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("SwiftOpenAI/0.2.0", forHTTPHeaderField: "User-Agent")

        if let organization = configuration.organization {
            request.setValue(organization, forHTTPHeaderField: "OpenAI-Organization")
        }
        if let project = configuration.project {
            request.setValue(project, forHTTPHeaderField: "OpenAI-Project")
        }

        self.client = WebSocketClient(session: session, request: request)
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    // MARK: - Connection Lifecycle

    /// Opens the underlying WebSocket connection.
    public func connect() async {
        await client.connect()
    }

    /// Closes the WebSocket connection gracefully.
    public func close() async {
        await client.close()
    }

    // MARK: - Create Response

    /// Sends a `response.create` event and returns a stream of server events.
    ///
    /// The stream yields `ResponseStreamEvent` objects until the response completes
    /// (signaled by `response.completed`, `response.failed`, or `response.incomplete`).
    ///
    /// - Parameters:
    ///   - model: The model to use.
    ///   - input: The input for this turn (text or items).
    ///   - instructions: Optional system instructions.
    ///   - maxOutputTokens: Maximum tokens to generate.
    ///   - temperature: Sampling temperature.
    ///   - topP: Nucleus sampling parameter.
    ///   - store: Whether to persist the response server-side.
    ///   - metadata: Optional key-value metadata.
    ///   - previousResponseId: ID of the previous response to continue from.
    ///   - tools: Tools available to the model.
    ///   - toolChoice: How the model should select tools.
    ///   - text: Text output configuration (e.g., structured outputs).
    ///   - truncation: Truncation strategy.
    ///   - contextManagement: Context management configuration.
    ///   - reasoning: Reasoning configuration.
    ///   - parallelToolCalls: Whether to run tool calls in parallel.
    ///   - maxToolCalls: Maximum number of tool calls.
    ///   - serviceTier: Service tier.
    ///   - generate: Set to `false` for warmup (prepares state without output).
    /// - Returns: An `AsyncThrowingStream` of `ResponseStreamEvent` objects.
    public func create(
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
    ) async throws -> AsyncThrowingStream<ResponseStreamEvent, Error> {
        let event = ResponsesClientEvent(
            model: model,
            input: input,
            instructions: instructions,
            maxOutputTokens: maxOutputTokens,
            temperature: temperature,
            topP: topP,
            store: store,
            metadata: metadata,
            previousResponseId: previousResponseId,
            tools: tools,
            toolChoice: toolChoice,
            text: text,
            truncation: truncation,
            contextManagement: contextManagement,
            reasoning: reasoning,
            parallelToolCalls: parallelToolCalls,
            maxToolCalls: maxToolCalls,
            serviceTier: serviceTier,
            generate: generate
        )

        guard !isInFlight else {
            throw OpenAIError.connectionError(message: "A response is already in-flight on this WebSocket connection")
        }
        isInFlight = true
        try await sendEncodable(event)

        let decoder = self.decoder
        let client = self.client

        return AsyncThrowingStream { continuation in
            let receiveTask = Task {
                defer { Task { self.setInFlight(false) } }
                do {
                    while !Task.isCancelled {
                        let data = try await receiveRawData(client: client)
                        guard let data else {
                            continuation.finish()
                            return
                        }

                        // Check for error event first
                        if let errorEvent = try? decoder.decode(WebSocketErrorEvent.self, from: data),
                           errorEvent.type == "error" {
                            continuation.finish(throwing: OpenAIError.apiError(
                                statusCode: errorEvent.status ?? 400,
                                message: errorEvent.error.message,
                                type: errorEvent.error.type,
                                code: errorEvent.error.code
                            ))
                            return
                        }

                        let streamEvent = try decoder.decode(ResponseStreamEvent.self, from: data)
                        continuation.yield(streamEvent)

                        // Terminal events
                        if streamEvent.type == "response.completed" ||
                           streamEvent.type == "response.failed" ||
                           streamEvent.type == "response.incomplete" {
                            continuation.finish()
                            return
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable termination in
                receiveTask.cancel()
                guard case .cancelled = termination else { return }
                Task { await self.drainCurrentResponse(client: client, decoder: decoder) }
            }
        }
    }

    // MARK: - Warmup

    /// Warms up request state without generating a response.
    ///
    /// Returns the response ID that can be used as `previousResponseId` on
    /// the next turn to benefit from pre-warmed state.
    ///
    /// - Parameters:
    ///   - model: The model to use.
    ///   - input: The input to warm up with.
    ///   - instructions: Optional system instructions.
    ///   - tools: Tools to pre-register.
    ///   - store: Whether to persist.
    /// - Returns: The response ID from the warmup.
    public func warmup(
        model: String,
        input: ResponseInput,
        instructions: String? = nil,
        tools: [ResponseTool]? = nil,
        store: Bool? = nil
    ) async throws -> String {
        let stream = try await create(
            model: model,
            input: input,
            instructions: instructions,
            store: store,
            tools: tools,
            generate: false
        )

        var responseId: String?
        for try await event in stream {
            if let id = event.response?.id {
                responseId = id
            }
        }

        guard let id = responseId else {
            throw OpenAIError.decodingError(message: "Warmup did not return a response ID")
        }
        return id
    }

    // MARK: - Low-Level Send/Receive

    /// Sends an encodable value as JSON text over the WebSocket.
    public func send<T: Encodable & Sendable>(_ value: T) async throws {
        try await sendEncodable(value)
    }

    /// Receives and decodes the next JSON message.
    public func receive<T: Decodable & Sendable>(_ type: T.Type) async throws -> T {
        let message = try await client.receive()
        let data: Data

        switch message {
        case .string(let text):
            guard let textData = text.data(using: .utf8) else {
                throw OpenAIError.decodingError(message: "Failed to decode WebSocket text as UTF-8")
            }
            data = textData
        case .data(let binaryData):
            data = binaryData
        @unknown default:
            throw OpenAIError.connectionError(message: "Unsupported WebSocket message type")
        }

        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw OpenAIError.decodingError(message: "Failed to decode WebSocket message: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    private func setInFlight(_ value: Bool) {
        isInFlight = value
    }

    /// Drains messages for the current in-flight response, discarding them until a
    /// terminal event or connection close. Used on early stream cancellation to keep
    /// the WebSocket connection clean for the next `create()` call.
    private func drainCurrentResponse(client: WebSocketClient, decoder: JSONDecoder) async {
        defer { isInFlight = false }
        guard isInFlight else { return }
        while true {
            do {
                guard let data = try await receiveRawData(client: client) else { return }
                if let event = try? decoder.decode(ResponseStreamEvent.self, from: data) {
                    if event.type == "response.completed" ||
                       event.type == "response.failed" ||
                       event.type == "response.incomplete" {
                        return
                    }
                }
                if let errorEvent = try? decoder.decode(WebSocketErrorEvent.self, from: data),
                   errorEvent.type == "error" {
                    return
                }
            } catch {
                return
            }
        }
    }

    private func sendEncodable<T: Encodable & Sendable>(_ value: T) async throws {
        let data: Data
        do {
            data = try encoder.encode(value)
        } catch {
            throw OpenAIError.decodingError(message: "Failed to encode WebSocket payload: \(error.localizedDescription)")
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw OpenAIError.decodingError(message: "Failed to encode WebSocket payload as UTF-8")
        }
        try await client.send(.string(text))
    }
}

/// Receives raw data from a WebSocketClient, returning nil on connection close.
private func receiveRawData(client: WebSocketClient) async throws -> Data? {
    let message: URLSessionWebSocketTask.Message
    do {
        message = try await client.receive()
    } catch {
        let nsError = error as NSError
        // Connection closed/cancelled codes
        if nsError.code == 57 || nsError.code == 54 || nsError.code == -999 {
            return nil
        }
        throw error
    }

    switch message {
    case .string(let text):
        return text.data(using: .utf8)
    case .data(let data):
        return data
    @unknown default:
        return nil
    }
}

#endif
