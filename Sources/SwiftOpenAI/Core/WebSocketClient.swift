import Foundation

#if canImport(Darwin)

actor WebSocketClient {

    private let session: URLSession
    private let request: URLRequest
    private var task: URLSessionWebSocketTask?

    init(session: URLSession, request: URLRequest) {
        self.session = session
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

    func close(code: URLSessionWebSocketTask.CloseCode = .normalClosure, reason: Data? = nil) {
        task?.cancel(with: code, reason: reason)
        task = nil
    }
}

#endif
