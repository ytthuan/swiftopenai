import Foundation

#if canImport(Darwin)

actor WebSocketClient {

    private let session: URLSession
    private var request: URLRequest
    private var task: URLSessionWebSocketTask?
    private var keepaliveTask: Task<Void, Never>?
    private var lastPongAt: Date = Date()

    init(session: URLSession, request: URLRequest) {
        self.session = session
        self.request = request
    }

    /// Updates the stored request (e.g., to refresh auth headers before connecting).
    func updateRequest(_ request: URLRequest) {
        self.request = request
    }

    func connect() {
        guard task == nil else { return }
        let task = session.webSocketTask(with: request)
        task.maximumMessageSize = 10 * 1024 * 1024
        self.task = task
        task.resume()
    }

    func send(_ message: URLSessionWebSocketTask.Message) async throws {
        guard let task else {
            throw OpenAIError.connectionError(message: "WebSocket is not connected")
        }
        try await task.send(message)
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        guard let task else {
            throw OpenAIError.connectionError(message: "WebSocket is not connected")
        }
        return try await task.receive()
    }

    /// Starts periodic keepalive pings to prevent idle connection drops.
    /// - Parameter interval: Time between pings in seconds (default: 30).
    func startKeepalive(interval: TimeInterval = 30) {
        stopKeepalive()
        let taskRef = task
        lastPongAt = Date()
        keepaliveTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled, let taskRef, let self else { break }
                // Detect dead connection: no pong received within 2× the ping interval
                let elapsed = Date().timeIntervalSince(await self.lastPongAt)
                if elapsed > 2 * interval {
                    taskRef.cancel(with: .goingAway, reason: nil)
                    break
                }
                try? await taskRef.sendPing { [weak self] error in
                    if error == nil {
                        Task { await self?.recordPong() }
                    }
                }
            }
        }
    }

    /// Records the receipt of a pong response.
    private func recordPong() {
        lastPongAt = Date()
    }

    /// Stops keepalive pings.
    func stopKeepalive() {
        keepaliveTask?.cancel()
        keepaliveTask = nil
    }

    func close(code: URLSessionWebSocketTask.CloseCode = .normalClosure, reason: Data? = nil) {
        stopKeepalive()
        task?.cancel(with: code, reason: reason)
        task = nil
    }
}

#endif
