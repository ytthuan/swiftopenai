import Foundation

/// Namespace for Chat API resources.
public struct Chat: Sendable {

    /// Access chat completions.
    public let completions: ChatCompletions

    init(client: HTTPClient) {
        self.completions = ChatCompletions(client: client)
    }
}
