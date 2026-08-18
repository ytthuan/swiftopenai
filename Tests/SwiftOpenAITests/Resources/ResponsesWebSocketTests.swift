import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SwiftOpenAI

// MARK: - WebSocket Types Tests

@Suite struct WebSocketTypesTests {

    // MARK: - ResponsesClientEvent Encoding

    @Test func clientEventEncodesTypeField() throws {
        let event = ResponsesClientEvent(
            model: "gpt-5.2",
            input: .text("Hello")
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["type"] as? String == "response.create")
        #expect(json["model"] as? String == "gpt-5.2")
    }

    @Test func clientEventEncodesAllFields() throws {
        let event = ResponsesClientEvent(
            model: "gpt-5.2",
            input: .text("Hello"),
            instructions: "Be helpful",
            maxOutputTokens: 1000,
            temperature: 0.7,
            topP: 0.9,
            store: false,
            metadata: ["key": "value"],
            previousResponseId: "resp_123",
            generate: false
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["type"] as? String == "response.create")
        #expect(json["model"] as? String == "gpt-5.2")
        #expect(json["instructions"] as? String == "Be helpful")
        #expect(json["max_output_tokens"] as? Int == 1000)
        #expect(json["temperature"] as? Double == 0.7)
        #expect(json["top_p"] as? Double == 0.9)
        #expect(json["store"] as? Bool == false)
        #expect(json["previous_response_id"] as? String == "resp_123")
        #expect(json["generate"] as? Bool == false)
        let metadata = json["metadata"] as? [String: String]
        #expect(metadata?["key"] == "value")
    }

    @Test func clientEventOmitsNilFields() throws {
        let event = ResponsesClientEvent(
            model: "gpt-5.2",
            input: .text("Hello")
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Only type, model, and input should be present
        #expect(json["instructions"] == nil)
        #expect(json["max_output_tokens"] == nil)
        #expect(json["store"] == nil)
        #expect(json["generate"] == nil)
        #expect(json["previous_response_id"] == nil)
    }

    @Test func clientEventWithFunctionTool() throws {
        let tool = ResponseTool.function(FunctionToolDefinition(
            name: "get_weather",
            description: "Get weather",
            parameters: [
                "type": AnyCodable("object"),
                "properties": AnyCodable([
                    "city": AnyCodable(["type": AnyCodable("string")] as [String: AnyCodable])
                ] as [String: AnyCodable]),
            ],
            strict: true
        ))
        let event = ResponsesClientEvent(
            model: "gpt-5.2",
            input: .text("Weather in Tokyo?"),
            tools: [tool]
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let tools = json["tools"] as? [[String: Any]]
        #expect(tools?.count == 1)
        #expect(tools?.first?["type"] as? String == "function")
    }

    // MARK: - WebSocketErrorEvent Decoding

    @Test func errorEventDecodes() throws {
        let json = """
        {
            "type": "error",
            "status": 400,
            "error": {
                "type": "invalid_request_error",
                "code": "previous_response_not_found",
                "message": "Previous response with id 'resp_abc' not found.",
                "param": "previous_response_id"
            }
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let event = try decoder.decode(WebSocketErrorEvent.self, from: json.data(using: .utf8)!)

        #expect(event.type == "error")
        #expect(event.status == 400)
        #expect(event.error.type == "invalid_request_error")
        #expect(event.error.code == "previous_response_not_found")
        #expect(event.error.message == "Previous response with id 'resp_abc' not found.")
        #expect(event.error.param == "previous_response_id")
    }

    @Test func connectionLimitErrorDecodes() throws {
        let json = """
        {
            "type": "error",
            "status": 400,
            "error": {
                "type": "invalid_request_error",
                "code": "websocket_connection_limit_reached",
                "message": "Responses websocket connection limit reached (60 minutes). Create a new websocket connection to continue."
            }
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let event = try decoder.decode(WebSocketErrorEvent.self, from: json.data(using: .utf8)!)

        #expect(event.error.code == "websocket_connection_limit_reached")
        #expect(event.error.param == nil)
    }

    // MARK: - WebSocketConnectionState

    @Test func connectionStatesExist() {
        let states: [WebSocketConnectionState] = [.disconnected, .connecting, .connected, .closing]
        #expect(states.count == 4)
    }

    // MARK: - Configuration WebSocket URL

    #if canImport(Darwin)
    @Test func httpsConvertsToWss() {
        let config = Configuration(apiKey: "test", baseURL: URL(string: "https://api.openai.com/v1")!)
        let wsURL = config.websocketBaseURL
        #expect(wsURL.scheme == "wss")
        #expect(wsURL.host == "api.openai.com")
        #expect(wsURL.path == "/v1" || wsURL.path.hasPrefix("/v1"))
    }

    @Test func httpLocalhostConvertsToWsWhenInsecureAllowed() {
        let config = Configuration(
            apiKey: "test",
            baseURL: URL(string: "http://localhost:8080/v1")!,
            allowInsecureRequests: true
        )
        let wsURL = config.websocketBaseURL
        #expect(wsURL.scheme == "ws")
        #expect(wsURL.host == "localhost")
        #expect(wsURL.port == 8080)
    }

    @Test func customAzureBaseURLConverts() {
        let config = Configuration(
            apiKey: "test",
            baseURL: URL(string: "https://my-resource.openai.azure.com/openai/v1")!
        )
        let wsURL = config.websocketBaseURL
        #expect(wsURL.scheme == "wss")
        #expect(wsURL.host == "my-resource.openai.azure.com")
        #expect(wsURL.path.contains("openai"))
    }
    #endif

    // MARK: - connectWebSocket Availability

    #if canImport(Darwin)
    @Test func connectWebSocketReturnsActor() {
        let client = OpenAI(apiKey: "test-key")
        let ws = client.responses.connectWebSocket()
        // Just verify it returns a ResponsesWebSocket without crashing
        _ = ws
    }
    #endif
}

#if canImport(Darwin)

private actor ScriptedResponsesWebSocketTransport: ResponsesWebSocketTransport {
    private struct ReceiveWaiter {
        let id: UInt64
        let continuation: CheckedContinuation<ResponsesWebSocketTransportMessage, any Error>
    }

    private struct CountWaiter {
        let target: Int
        let continuation: CheckedContinuation<Void, any Error>
    }

    private var queuedMessages: [ResponsesWebSocketTransportMessage]
    private var receiveWaiters: [ReceiveWaiter] = []
    private var receiveCountWaiters: [UInt64: CountWaiter] = [:]
    private var cancellationCountWaiters: [UInt64: CountWaiter] = [:]
    private var nextID: UInt64 = 0
    private var receiveCount = 0
    private var cancellationCount = 0
    private var sentPayloads: [String] = []

    init(messages: [ResponsesWebSocketTransportMessage] = []) {
        self.queuedMessages = messages
    }

    func transportConnect(request: URLRequest) async {}

    func transportClose() async {
        let waiters = receiveWaiters
        receiveWaiters.removeAll()
        for waiter in waiters {
            waiter.continuation.resume(returning: .closed)
        }
    }

    func transportSend(text: String) async throws {
        sentPayloads.append(text)
    }

    func transportReceive() async throws -> ResponsesWebSocketTransportMessage {
        receiveCount += 1
        resumeCountWaiters(&receiveCountWaiters, currentCount: receiveCount)

        nextID &+= 1
        let receiveID = nextID
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else if queuedMessages.isEmpty {
                    receiveWaiters.append(
                        ReceiveWaiter(id: receiveID, continuation: continuation)
                    )
                } else {
                    continuation.resume(returning: queuedMessages.removeFirst())
                }
            }
        } onCancel: {
            Task {
                await self.cancelReceive(id: receiveID)
            }
        }
    }

    func enqueue(_ message: ResponsesWebSocketTransportMessage) {
        if receiveWaiters.isEmpty {
            queuedMessages.append(message)
        } else {
            let waiter = receiveWaiters.removeFirst()
            waiter.continuation.resume(returning: message)
        }
    }

    func waitForReceiveCount(_ target: Int) async throws {
        guard receiveCount < target else { return }
        nextID &+= 1
        let waiterID = nextID
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, any Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else if receiveCount >= target {
                    continuation.resume()
                } else {
                    receiveCountWaiters[waiterID] = CountWaiter(
                        target: target,
                        continuation: continuation
                    )
                }
            }
        } onCancel: {
            Task {
                await self.cancelCountWaiter(id: waiterID, receive: true)
            }
        }
    }

    func waitForCancellationCount(_ target: Int) async throws {
        guard cancellationCount < target else { return }
        nextID &+= 1
        let waiterID = nextID
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, any Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else if cancellationCount >= target {
                    continuation.resume()
                } else {
                    cancellationCountWaiters[waiterID] = CountWaiter(
                        target: target,
                        continuation: continuation
                    )
                }
            }
        } onCancel: {
            Task {
                await self.cancelCountWaiter(id: waiterID, receive: false)
            }
        }
    }

    func sentPayloadsSnapshot() -> [String] {
        sentPayloads
    }

    func receiveCountSnapshot() -> Int {
        receiveCount
    }

    private func cancelReceive(id: UInt64) {
        guard let index = receiveWaiters.firstIndex(where: { $0.id == id }) else {
            return
        }
        let waiter = receiveWaiters.remove(at: index)
        cancellationCount += 1
        resumeCountWaiters(&cancellationCountWaiters, currentCount: cancellationCount)
        waiter.continuation.resume(throwing: CancellationError())
    }

    private func cancelCountWaiter(id: UInt64, receive: Bool) {
        let waiter = receive
            ? receiveCountWaiters.removeValue(forKey: id)
            : cancellationCountWaiters.removeValue(forKey: id)
        waiter?.continuation.resume(throwing: CancellationError())
    }

    private func resumeCountWaiters(
        _ waiters: inout [UInt64: CountWaiter],
        currentCount: Int
    ) {
        let readyIDs = waiters.compactMap { id, waiter in
            currentCount >= waiter.target ? id : nil
        }
        for id in readyIDs {
            waiters.removeValue(forKey: id)?.continuation.resume()
        }
    }
}

@Suite(.timeLimit(.minutes(1)))
struct ResponsesWebSocketTransportStateTests {
    private var request: ResponseCreateRequest {
        ResponseCreateRequest(
            model: "gpt-5.6-sol",
            legacyInput: ResponseInput.text("hello")
        )
    }

    private func socket(
        transport: ScriptedResponsesWebSocketTransport
    ) -> ResponsesWebSocket {
        ResponsesWebSocket(
            configuration: Configuration(apiKey: "sk-test-websocket"),
            transport: transport
        )
    }

    private func terminal(sequenceNumber: Int, responseID: String? = nil) -> String {
        guard let responseID else {
            return #"{"type":"response.completed","sequence_number":\#(sequenceNumber)}"#
        }
        return """
        {
          "type": "response.completed",
          "sequence_number": \(sequenceNumber),
          "response": {
            "id": "\(responseID)",
            "object": "response",
            "created_at": 1,
            "model": "gpt-5.6-sol",
            "output": [],
            "status": "completed"
          }
        }
        """
    }

    private func collect(
        _ stream: AsyncThrowingStream<ResponseStreamEvent, any Error>
    ) async throws -> [ResponseStreamEvent] {
        var events: [ResponseStreamEvent] = []
        for try await event in stream {
            events.append(event)
        }
        return events
    }

    private func createAfterCleanup(
        on socket: ResponsesWebSocket
    ) async throws -> AsyncThrowingStream<ResponseStreamEvent, any Error> {
        var lastCleanupError: OpenAIError?
        for _ in 0..<256 {
            do {
                return try await socket.create(request: request)
            } catch let error as OpenAIError {
                let cleanupStillActive =
                    error == .connectionError(
                        message: "A response is already in-flight on this WebSocket connection"
                    ) ||
                    error == .connectionError(
                        message: "A WebSocket receive operation is already active"
                    )
                guard cleanupStillActive else { throw error }
                lastCleanupError = error
                await Task.yield()
            }
        }
        throw lastCleanupError ?? OpenAIError.connectionError(
            message: "WebSocket cleanup did not complete"
        )
    }

    @Test func terminalCompletionClearsInFlightAndPermitsSubsequentCreate() async throws {
        let transport = ScriptedResponsesWebSocketTransport(messages: [
            .string(terminal(sequenceNumber: 1)),
        ])
        let websocket = socket(transport: transport)

        let firstStream = try await websocket.create(request: request)
        let firstEvents = try await collect(firstStream)
        let secondStream = try await websocket.create(request: request)
        await transport.enqueue(.string(terminal(sequenceNumber: 2)))
        let secondEvents = try await collect(secondStream)
        let sentPayloads = await transport.sentPayloadsSnapshot()

        #expect(firstEvents.map(\.sequenceNumber) == [1])
        #expect(secondEvents.map(\.sequenceNumber) == [2])
        #expect(sentPayloads.count == 2)
    }

    @Test func legacyWarmupCompletionPermitsOfficialRequestCreate() async throws {
        let transport = ScriptedResponsesWebSocketTransport(messages: [
            .string(terminal(sequenceNumber: 1, responseID: "resp_warm")),
        ])
        let websocket = socket(transport: transport)

        let responseID = try await websocket.warmup(
            model: "gpt-5.6-sol",
            input: .text("hello")
        )
        let nextStream = try await websocket.create(request: request)
        await transport.enqueue(.string(terminal(sequenceNumber: 2)))
        let nextEvents = try await collect(nextStream)
        let sentPayloads = await transport.sentPayloadsSnapshot()
        let warmupPayload = try #require(sentPayloads.first)
        let createPayload = try #require(sentPayloads.dropFirst().first)
        let warmupData = Data(warmupPayload.utf8)
        let createData = Data(createPayload.utf8)
        let warmupJSON = try #require(
            JSONSerialization.jsonObject(with: warmupData) as? [String: Any]
        )
        let createJSON = try #require(
            JSONSerialization.jsonObject(with: createData) as? [String: Any]
        )

        #expect(responseID == "resp_warm")
        #expect(warmupJSON["generate"] as? Bool == false)
        #expect(createJSON["type"] as? String == "response.create")
        #expect(createJSON["model"] as? String == "gpt-5.6-sol")
        #expect(createJSON["generate"] == nil)
        #expect(nextEvents.map(\.sequenceNumber) == [2])
        #expect(sentPayloads.count == 2)
    }

    @Test func cancellationDrainsUntilTerminalThenPermitsNextCreate() async throws {
        let transport = ScriptedResponsesWebSocketTransport()
        let websocket = socket(transport: transport)
        let stream = try await websocket.create(request: request)
        let consumer = Task {
            try await collect(stream)
        }
        try await transport.waitForReceiveCount(1)

        consumer.cancel()
        _ = await consumer.result
        try await transport.waitForCancellationCount(1)
        try await transport.waitForReceiveCount(2)
        await transport.enqueue(.string(#"{"type":"response.output_text.delta","delta":"discard"}"#))
        try await transport.waitForReceiveCount(3)
        await transport.enqueue(.string(terminal(sequenceNumber: 1)))

        let nextStream = try await createAfterCleanup(on: websocket)
        await transport.enqueue(.string(terminal(sequenceNumber: 2)))
        let nextEvents = try await collect(nextStream)

        #expect(nextEvents.map(\.sequenceNumber) == [2])
    }

    @Test func cancellationConcurrentWithTerminalCannotStickCleanup() async throws {
        let transport = ScriptedResponsesWebSocketTransport()
        let websocket = socket(transport: transport)
        let stream = try await websocket.create(request: request)
        let consumer = Task {
            try await collect(stream)
        }
        try await transport.waitForReceiveCount(1)
        let terminalEvent = terminal(sequenceNumber: 1)

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                consumer.cancel()
            }
            group.addTask {
                await transport.enqueue(.string(terminalEvent))
            }
        }
        _ = await consumer.result

        let nextStream = try await createAfterCleanup(on: websocket)
        await transport.enqueue(.string(terminal(sequenceNumber: 2)))
        let nextEvents = try await collect(nextStream)

        #expect(nextEvents.map(\.sequenceNumber) == [2])
    }

    @Test func lowLevelReceiveIsRejectedWhileDrainOwnsTerminal() async throws {
        let transport = ScriptedResponsesWebSocketTransport()
        let websocket = socket(transport: transport)
        let stream = try await websocket.create(request: request)
        let consumer = Task {
            try await collect(stream)
        }
        try await transport.waitForReceiveCount(1)
        consumer.cancel()
        _ = await consumer.result
        try await transport.waitForCancellationCount(1)
        try await transport.waitForReceiveCount(2)

        let lowLevelError: OpenAIError?
        do {
            _ = try await websocket.receive(ResponseStreamEvent.self)
            lowLevelError = nil
        } catch let error as OpenAIError {
            lowLevelError = error
        } catch {
            lowLevelError = nil
        }

        await transport.enqueue(.string(terminal(sequenceNumber: 1)))
        let nextStream = try await createAfterCleanup(on: websocket)
        await transport.enqueue(.string(terminal(sequenceNumber: 2)))
        let nextEvents = try await collect(nextStream)
        let receiveCount = await transport.receiveCountSnapshot()

        #expect(lowLevelError == .connectionError(
            message: "Cannot receive directly while a response receive or drain is active"
        ))
        #expect(nextEvents.map(\.sequenceNumber) == [2])
        #expect(receiveCount == 3)
    }

    @Test func createRejectsASecondInFlightResponse() async throws {
        let transport = ScriptedResponsesWebSocketTransport()
        let websocket = socket(transport: transport)
        let firstStream = try await websocket.create(request: request)

        let secondCreateError: OpenAIError?
        do {
            _ = try await websocket.create(request: request)
            secondCreateError = nil
        } catch let error as OpenAIError {
            secondCreateError = error
        }

        await transport.enqueue(.string(terminal(sequenceNumber: 1)))
        let firstEvents = try await collect(firstStream)
        let sentPayloads = await transport.sentPayloadsSnapshot()

        #expect(secondCreateError == .connectionError(
            message: "A response is already in-flight on this WebSocket connection"
        ))
        #expect(firstEvents.map(\.sequenceNumber) == [1])
        #expect(sentPayloads.count == 1)
    }
}

#endif
