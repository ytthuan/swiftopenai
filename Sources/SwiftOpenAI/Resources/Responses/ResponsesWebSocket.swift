import Foundation

#if canImport(Darwin)

enum ResponsesWebSocketTransportMessage: Sendable {
    case string(String)
    case data(Data)
    case closed
}

protocol ResponsesWebSocketTransport: Sendable {
    func transportConnect(request: URLRequest) async
    func transportClose() async
    func transportSend(text: String) async throws
    func transportReceive() async throws -> ResponsesWebSocketTransportMessage
}

extension WebSocketClient: ResponsesWebSocketTransport {
    func transportConnect(request: URLRequest) {
        updateRequest(request)
        connect()
    }

    func transportClose() {
        close()
    }

    func transportSend(text: String) async throws {
        try await send(.string(text))
    }

    func transportReceive() async throws -> ResponsesWebSocketTransportMessage {
        switch try await receive() {
        case .string(let text):
            return .string(text)
        case .data(let data):
            return .data(data)
        @unknown default:
            return .closed
        }
    }
}

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
/// try await ws.connect()
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

    private enum ResponseState: Equatable {
        case receiving(UInt64)
        case cancellationRequested(UInt64)
        case draining(UInt64)
    }

    private enum ReceiveOwner: Equatable {
        case response(UInt64)
        case drain(UInt64)
        case lowLevel
    }

    private enum ReceiveOutcome: Sendable {
        case event(ResponseStreamEvent)
        case terminal(ResponseStreamEvent)
        case closed
        case failure(OpenAIError)
        case cancelledBeforeOutcome
        case superseded
    }

    private let transport: any ResponsesWebSocketTransport
    private let configuration: Configuration
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var responseState: ResponseState?
    private var receiveOwner: ReceiveOwner?
    private var nextResponseID: UInt64 = 0

    init(configuration: Configuration, session: URLSession) {
        var request = URLRequest(url: configuration.websocketBaseURL.appendingPathComponent("responses"))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SDK.userAgent, forHTTPHeaderField: "User-Agent")

        if let organization = configuration.organization {
            request.setValue(organization.replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: "\n", with: ""), forHTTPHeaderField: "OpenAI-Organization")
        }
        if let project = configuration.project {
            request.setValue(project.replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: "\n", with: ""), forHTTPHeaderField: "OpenAI-Project")
        }

        self.configuration = configuration
        self.transport = WebSocketClient(session: session, request: request)
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    init(configuration: Configuration, transport: any ResponsesWebSocketTransport) {
        self.configuration = configuration
        self.transport = transport
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    // MARK: - Connection Lifecycle

    /// Opens the underlying WebSocket connection.
    public func connect() async throws {
        let token: String
        if let provider = configuration.tokenProvider {
            token = try await provider.getToken()
        } else {
            token = configuration.apiKey
        }
        var request = URLRequest(url: configuration.websocketBaseURL.appendingPathComponent("responses"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SDK.userAgent, forHTTPHeaderField: "User-Agent")
        if let organization = configuration.organization {
            request.setValue(organization.replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: "\n", with: ""), forHTTPHeaderField: "OpenAI-Organization")
        }
        if let project = configuration.project {
            request.setValue(project.replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: "\n", with: ""), forHTTPHeaderField: "OpenAI-Project")
        }
        await transport.transportConnect(request: request)
    }

    /// Closes the WebSocket connection gracefully.
    public func close() async {
        await transport.transportClose()
    }

    // MARK: - Create Response

    /// Sends an official flat `response.create` event from a Responses request.
    ///
    /// - Parameter request: The Responses request to send.
    /// - Returns: A stream of response server events.
    public func create(
        request: ResponseCreateRequest
    ) async throws -> AsyncThrowingStream<ResponseStreamEvent, Error> {
        try await start(ResponseWebSocketCreateRequest(request: request))
    }

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
    ///   - generate: Legacy compatibility option for the pre-existing Swift wire format.
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
        truncation: TruncationStrategy? = nil,
        contextManagement: [ContextManagement]? = nil,
        reasoning: ReasoningConfig? = nil,
        parallelToolCalls: Bool? = nil,
        maxToolCalls: Int? = nil,
        serviceTier: ServiceTier? = nil,
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
        return try await start(event)
    }

    // MARK: - Warmup

    /// Warms up request state using the legacy Swift WebSocket wire format.
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

        return try await responseID(from: stream)
    }

    // MARK: - Low-Level Send/Receive

    /// Sends an encodable value as JSON text over the WebSocket.
    public func send<T: Encodable & Sendable>(_ value: T) async throws {
        try await sendEncodable(value)
    }

    /// Receives and decodes the next JSON message.
    public func receive<T: Decodable & Sendable>(_ type: T.Type) async throws -> T {
        guard responseState == nil else {
            throw OpenAIError.connectionError(
                message: "Cannot receive directly while a response receive or drain is active"
            )
        }
        guard receiveOwner == nil else {
            throw OpenAIError.connectionError(message: "A WebSocket receive operation is already active")
        }
        receiveOwner = .lowLevel
        defer {
            if receiveOwner == .lowLevel {
                receiveOwner = nil
            }
        }

        let message = try await transport.transportReceive()
        let data: Data

        switch message {
        case .string(let text):
            guard let textData = text.data(using: .utf8) else {
                throw OpenAIError.decodingError(message: "Failed to decode WebSocket text as UTF-8")
            }
            data = textData
        case .data(let binaryData):
            data = binaryData
        case .closed:
            throw OpenAIError.connectionError(message: "WebSocket connection closed")
        }

        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw OpenAIError.decodingError(message: "Failed to decode WebSocket message: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    private func start<Event: Encodable & Sendable>(
        _ event: Event
    ) async throws -> AsyncThrowingStream<ResponseStreamEvent, Error> {
        guard responseState == nil else {
            throw OpenAIError.connectionError(message: "A response is already in-flight on this WebSocket connection")
        }
        guard receiveOwner == nil else {
            throw OpenAIError.connectionError(message: "A WebSocket receive operation is already active")
        }

        nextResponseID &+= 1
        let responseID = nextResponseID
        responseState = .receiving(responseID)
        do {
            try await sendEncodable(event)
        } catch {
            completeResponse(responseID)
            throw error
        }

        return AsyncThrowingStream { continuation in
            let receiveTask = Task {
                while true {
                    let outcome = await self.receiveNextOutcome(responseID: responseID)
                    switch outcome {
                    case .event(let streamEvent):
                        continuation.yield(streamEvent)
                        if Task.isCancelled {
                            return
                        }
                    case .terminal(let streamEvent):
                        continuation.yield(streamEvent)
                        continuation.finish()
                        return
                    case .closed:
                        continuation.finish()
                        return
                    case .failure(let error):
                        continuation.finish(throwing: error)
                        return
                    case .cancelledBeforeOutcome, .superseded:
                        return
                    }
                }
            }

            continuation.onTermination = { @Sendable termination in
                guard case .cancelled = termination else { return }
                Task {
                    await self.requestConsumerCancellation(responseID: responseID)
                    receiveTask.cancel()
                    _ = await receiveTask.result
                    await self.drainResponseIfNeeded(responseID: responseID)
                }
            }
        }
    }

    private func responseID(
        from stream: AsyncThrowingStream<ResponseStreamEvent, Error>
    ) async throws -> String {
        var responseId: String?
        for try await event in stream {
            if let id = event.response?.id {
                responseId = id
            }
        }
        guard let responseId else {
            throw OpenAIError.decodingError(message: "Warmup did not return a response ID")
        }
        return responseId
    }

    private func receiveNextOutcome(responseID: UInt64) async -> ReceiveOutcome {
        guard responseStateMatches(responseID), receiveOwner == nil else {
            return .superseded
        }
        receiveOwner = .response(responseID)

        let message: ResponsesWebSocketTransportMessage
        do {
            message = try await transport.transportReceive()
        } catch {
            releaseReceiveOwner(.response(responseID))
            let errorCode = (error as NSError).code
            if Task.isCancelled && (error is CancellationError || errorCode == -999) {
                return .cancelledBeforeOutcome
            }
            completeResponse(responseID)
            if isConnectionCloseError(error) {
                return .closed
            }
            if let openAIError = error as? OpenAIError {
                return .failure(openAIError)
            }
            return .failure(.connectionError(message: "\(error)"))
        }

        releaseReceiveOwner(.response(responseID))

        guard let data = data(from: message) else {
            completeResponse(responseID)
            return .closed
        }

        if let errorEvent = try? decoder.decode(WebSocketErrorEvent.self, from: data),
           errorEvent.type == "error" {
            completeResponse(responseID)
            return .failure(
                .apiError(
                    statusCode: errorEvent.status ?? 400,
                    message: errorEvent.error.message,
                    type: errorEvent.error.type,
                    code: errorEvent.error.code
                )
            )
        }

        let streamEvent: ResponseStreamEvent
        do {
            streamEvent = try decoder.decode(ResponseStreamEvent.self, from: data)
        } catch {
            completeResponse(responseID)
            return .failure(.decodingError(message: "\(error)"))
        }

        if isTerminal(streamEvent) {
            completeResponse(responseID)
            return .terminal(streamEvent)
        }
        return .event(streamEvent)
    }

    private func requestConsumerCancellation(responseID: UInt64) {
        guard responseState == .receiving(responseID) else { return }
        responseState = .cancellationRequested(responseID)
    }

    /// Drains messages for the current in-flight response, discarding them until a
    /// terminal event or connection close. Used on early stream cancellation to keep
    /// the WebSocket connection clean for the next `create()` call.
    private func drainResponseIfNeeded(responseID: UInt64) async {
        guard responseState == .cancellationRequested(responseID), receiveOwner == nil else {
            return
        }
        responseState = .draining(responseID)
        receiveOwner = .drain(responseID)
        defer {
            releaseReceiveOwner(.drain(responseID))
            completeResponse(responseID)
        }

        while true {
            do {
                let message = try await transport.transportReceive()
                guard let data = data(from: message) else { return }
                if let event = try? decoder.decode(ResponseStreamEvent.self, from: data) {
                    if isTerminal(event) {
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

    private func responseStateMatches(_ responseID: UInt64) -> Bool {
        responseState == .receiving(responseID) ||
            responseState == .cancellationRequested(responseID)
    }

    private func releaseReceiveOwner(_ owner: ReceiveOwner) {
        if receiveOwner == owner {
            receiveOwner = nil
        }
    }

    @discardableResult
    private func completeResponse(_ responseID: UInt64) -> Bool {
        guard responseStateMatches(responseID) || responseState == .draining(responseID) else {
            return false
        }
        responseState = nil
        return true
    }

    private func data(from message: ResponsesWebSocketTransportMessage) -> Data? {
        switch message {
        case .string(let text):
            return Data(text.utf8)
        case .data(let data):
            return data
        case .closed:
            return nil
        }
    }

    private func isTerminal(_ event: ResponseStreamEvent) -> Bool {
        event.type == "response.completed" ||
            event.type == "response.failed" ||
            event.type == "response.incomplete"
    }

    private func isConnectionCloseError(_ error: Error) -> Bool {
        let code = (error as NSError).code
        return code == 57 || code == 54 || code == -999
    }

    private func sendEncodable<T: Encodable & Sendable>(_ value: T) async throws {
        let data: Data
        do {
            data = try encoder.encode(value)
        } catch {
            throw OpenAIError.apiError(statusCode: 0, message: "Encoding failed: \(error)", type: nil, code: nil)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw OpenAIError.apiError(statusCode: 0, message: "Encoding produced non-UTF8 data", type: nil, code: nil)
        }
        try await transport.transportSend(text: text)
    }
}

#endif
