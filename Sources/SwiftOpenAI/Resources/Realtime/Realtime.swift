#if canImport(Darwin)
import Foundation

/// Realtime API client for low-latency bidirectional communication.
///
/// Supports speech-to-speech, text conversations, and audio transcription
/// over a persistent WebSocket connection.
///
/// Usage:
/// ```swift
/// let realtime = client.realtime.connect(model: "gpt-realtime")
/// let events = try await realtime.start()
///
/// // Update session config
/// try await realtime.sessionUpdate(RealtimeSessionConfig(
///     type: "realtime",
///     instructions: "You are a helpful assistant."
/// ))
///
/// // Send a text message
/// try await realtime.sendText("Hello!")
///
/// // Request a response
/// try await realtime.createResponse()
///
/// // Listen for events
/// for try await event in events {
///     switch event.type {
///     case "response.output_text.delta":
///         print(event.delta ?? "", terminator: "")
///     case "response.done":
///         print("\nResponse complete")
///     default:
///         break
///     }
/// }
/// ```
public actor RealtimeConnection {
    private let configuration: Configuration
    private let model: String
    private var session: URLSession?
    private var webSocketTask: URLSessionWebSocketTask?
    private var isConnected = false
    private let urlSession: URLSession
    
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    init(configuration: Configuration, model: String, session: URLSession) {
        self.configuration = configuration
        self.model = model
        let enc = JSONEncoder()
        enc.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = enc
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = dec
        self.urlSession = session
    }
    
    /// Starts the Realtime session and returns a stream of server events.
    ///
    /// The connection is established and a `session.created` event is expected
    /// as the first server event.
    public func start() async throws -> AsyncThrowingStream<RealtimeServerEvent, Error> {
        guard !isConnected else {
            throw OpenAIError.connectionError(message: "Realtime session already connected")
        }
        
        // Build WebSocket URL using Configuration's websocketBaseURL
        guard var components = URLComponents(url: configuration.websocketBaseURL, resolvingAgainstBaseURL: true) else {
            throw OpenAIError.connectionError(message: "Invalid Realtime base URL: \(configuration.websocketBaseURL)")
        }
        let basePath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        components.path = basePath + "/realtime"
        components.queryItems = [URLQueryItem(name: "model", value: model)]
        
        guard let url = components.url else {
            throw OpenAIError.connectionError(message: "Invalid Realtime URL from components")
        }
        
        var request = URLRequest(url: url)
        let token: String
        if let provider = configuration.tokenProvider {
            token = try await provider.getToken()
        } else {
            token = configuration.apiKey
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")
        request.setValue(SDK.userAgent, forHTTPHeaderField: "User-Agent")
        if let org = configuration.organization {
            request.setValue(org.replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: "\n", with: ""), forHTTPHeaderField: "OpenAI-Organization")
        }
        if let project = configuration.project {
            request.setValue(project.replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: "\n", with: ""), forHTTPHeaderField: "OpenAI-Project")
        }
        
        let newSession = urlSession
        self.session = newSession
        let task = newSession.webSocketTask(with: request)
        self.webSocketTask = task
        task.resume()
        self.isConnected = true
        
        let decoder = self.decoder
        let taskRef = task
        
        return AsyncThrowingStream { continuation in
            let receiveTask = Task { [weak self] in
                do {
                    while !Task.isCancelled {
                        let message = try await taskRef.receive()
                        switch message {
                        case .string(let text):
                            let data = Data(text.utf8)
                            let event: RealtimeServerEvent
                            do {
                                event = try decoder.decode(RealtimeServerEvent.self, from: data)
                            } catch {
                                continuation.finish(throwing: OpenAIError.decodingError(message: "\(error)"))
                                return
                            }
                            continuation.yield(event)
                            
                            // Check for terminal events
                            if event.type == "error" {
                                let msg = event.error?.message ?? "Unknown error"
                                continuation.finish(throwing: OpenAIError.apiError(
                                    statusCode: 0, message: msg,
                                    type: event.error?.type, code: event.error?.code
                                ))
                                return
                            }
                        case .data(let data):
                            let event: RealtimeServerEvent
                            do {
                                event = try decoder.decode(RealtimeServerEvent.self, from: data)
                            } catch {
                                continuation.finish(throwing: OpenAIError.decodingError(message: "\(error)"))
                                return
                            }
                            continuation.yield(event)
                        @unknown default:
                            break
                        }
                    }
                } catch {
                    if !Task.isCancelled {
                        let nsError = error as NSError
                        if nsError.code == 57 || nsError.code == 54 || nsError.code == -999 {
                            // Connection closed/cancelled
                        } else {
                            continuation.finish(throwing: OpenAIError.connectionError(message: "\(error)"))
                        }
                    }
                }
                continuation.finish()
                await self?.markDisconnected()
            }
            
            continuation.onTermination = { @Sendable _ in
                receiveTask.cancel()
                taskRef.cancel(with: .goingAway, reason: nil)
            }
        }
    }
    
    private func markDisconnected() {
        isConnected = false
        webSocketTask = nil
        session = nil
    }
    
    // MARK: - Send Client Events
    
    /// Sends a raw client event.
    public func send(_ event: RealtimeClientEvent) async throws {
        guard let task = webSocketTask, isConnected else {
            throw OpenAIError.connectionError(message: "Not connected to Realtime API")
        }
        let data = try encoder.encode(event)
        guard let text = String(data: data, encoding: .utf8) else {
            throw OpenAIError.apiError(statusCode: 0, message: "Encoding produced non-UTF8 data", type: nil, code: nil)
        }
        try await task.send(.string(text))
    }
    
    /// Updates the session configuration.
    public func sessionUpdate(_ config: RealtimeSessionConfig) async throws {
        try await send(.sessionUpdate(RealtimeSessionUpdateEvent(session: config)))
    }
    
    /// Sends a text message to the conversation.
    public func sendText(_ text: String, role: String = "user") async throws {
        let item = RealtimeConversationItem(
            type: "message",
            role: role,
            content: [RealtimeContentPart(type: "input_text", text: text)]
        )
        try await send(.conversationItemCreate(RealtimeConversationItemCreateEvent(item: item)))
    }
    
    /// Appends base64-encoded audio to the input buffer.
    public func appendAudio(_ base64Audio: String) async throws {
        try await send(.inputAudioBufferAppend(RealtimeInputAudioBufferAppendEvent(audio: base64Audio)))
    }
    
    /// Commits the input audio buffer.
    public func commitAudio() async throws {
        try await send(.inputAudioBufferCommit(RealtimeInputAudioBufferCommitEvent()))
    }
    
    /// Clears the input audio buffer.
    public func clearAudioBuffer() async throws {
        try await send(.inputAudioBufferClear(RealtimeInputAudioBufferClearEvent()))
    }
    
    /// Creates a conversation item.
    public func createItem(_ item: RealtimeConversationItem, after previousItemId: String? = nil) async throws {
        try await send(.conversationItemCreate(RealtimeConversationItemCreateEvent(item: item, previousItemId: previousItemId)))
    }
    
    /// Deletes a conversation item.
    public func deleteItem(_ itemId: String) async throws {
        try await send(.conversationItemDelete(RealtimeConversationItemDeleteEvent(itemId: itemId)))
    }
    
    /// Requests the model to generate a response.
    public func createResponse(_ config: RealtimeResponseConfig? = nil) async throws {
        try await send(.responseCreate(RealtimeResponseCreateEvent(response: config)))
    }
    
    /// Cancels the current response.
    public func cancelResponse() async throws {
        try await send(.responseCancel(RealtimeResponseCancelEvent()))
    }
    
    /// Closes the Realtime connection.
    public func close() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        isConnected = false
        webSocketTask = nil
        session = nil
    }
}

// MARK: - Realtime Resource

/// Resource for accessing the Realtime API.
///
/// Create a connection with `connect(model:)`, then start the session
/// and interact using client events.
public struct Realtime: Sendable {
    private let configuration: Configuration
    private let session: URLSession
    
    init(configuration: Configuration, session: URLSession) {
        self.configuration = configuration
        self.session = session
    }
    
    /// Creates a new Realtime connection for the specified model.
    ///
    /// - Parameter model: The model to use (e.g., "gpt-realtime", "gpt-4o-realtime-preview").
    /// - Returns: A `RealtimeConnection` actor for interacting with the session.
    public func connect(model: String) -> RealtimeConnection {
        RealtimeConnection(configuration: configuration, model: model, session: session)
    }
}
#endif
