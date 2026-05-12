import Foundation

/// Options for streaming chat completions.
///
/// Used to request additional data in the streaming response,
/// such as token usage statistics.
///
/// Usage:
/// ```swift
/// let options = ChatCompletionStreamOptions(includeUsage: true)
/// ```
public struct ChatCompletionStreamOptions: Codable, Sendable, Hashable {
    /// If set to `true`, an additional chunk will be streamed with
    /// `usage` information about the entire request.
    public var includeUsage: Bool?

    /// If set to `true`, includes obfuscation data in the stream.
    public var includeObfuscation: Bool?

    public init(includeUsage: Bool? = nil, includeObfuscation: Bool? = nil) {
        self.includeUsage = includeUsage
        self.includeObfuscation = includeObfuscation
    }
}
