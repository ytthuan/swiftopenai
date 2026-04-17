import Foundation

/// A message in a chat completion request.
///
/// Supports both simple text messages and multimodal messages with content parts
/// (text + images) via the `.userParts` case.
public enum ChatCompletionMessage: Codable, Sendable {
    case system(String)
    case user(String)
    /// A user message composed of multiple content parts (text, images, etc.).
    case userParts([ChatCompletionContentPart])
    case assistant(String?, toolCalls: [ChatCompletionToolCall]? = nil)
    case tool(String, toolCallId: String)
    case other(role: String, content: String?)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let role = try container.decode(String.self, forKey: .role)
        switch role {
        case "system":
            let content = try container.decode(String.self, forKey: .content)
            self = .system(content)
        case "user":
            if let content = try? container.decode(String.self, forKey: .content) {
                self = .user(content)
            } else if let parts = try? container.decode([ChatCompletionContentPart].self, forKey: .content) {
                self = .userParts(parts)
            } else {
                self = .user("")
            }
        case "assistant":
            let content = try container.decodeIfPresent(String.self, forKey: .content)
            let toolCalls = try container.decodeIfPresent([ChatCompletionToolCall].self, forKey: .toolCalls)
            self = .assistant(content, toolCalls: toolCalls)
        case "tool":
            let content = try container.decode(String.self, forKey: .content)
            let toolCallId = try container.decode(String.self, forKey: .toolCallId)
            self = .tool(content, toolCallId: toolCallId)
        default:
            let content = try container.decodeIfPresent(String.self, forKey: .content)
            self = .other(role: role, content: content)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .system(let content):
            try container.encode("system", forKey: .role)
            try container.encode(content, forKey: .content)
        case .user(let content):
            try container.encode("user", forKey: .role)
            try container.encode(content, forKey: .content)
        case .userParts(let parts):
            try container.encode("user", forKey: .role)
            try container.encode(parts, forKey: .content)
        case .assistant(let content, let toolCalls):
            try container.encode("assistant", forKey: .role)
            try container.encodeIfPresent(content, forKey: .content)
            try container.encodeIfPresent(toolCalls, forKey: .toolCalls)
        case .tool(let content, let toolCallId):
            try container.encode("tool", forKey: .role)
            try container.encode(content, forKey: .content)
            try container.encode(toolCallId, forKey: .toolCallId)
        case .other(let role, let content):
            try container.encode(role, forKey: .role)
            try container.encodeIfPresent(content, forKey: .content)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case role, content, toolCalls, toolCallId
    }

    // MARK: - Convenience Initializers

    /// Creates a user message with text and an image URL.
    ///
    /// Usage:
    /// ```swift
    /// let message: ChatCompletionMessage = .user(
    ///     text: "What's in this image?",
    ///     imageURL: "https://example.com/image.png",
    ///     detail: .high
    /// )
    /// ```
    /// - Parameters:
    ///   - text: The text content of the message.
    ///   - imageURL: The URL of the image (HTTP URL or base64 data URI).
    ///   - detail: The detail level for image processing. Defaults to `nil`.
    /// - Returns: A `.userParts` message containing a text part and an image URL part.
    public static func user(text: String, imageURL: String, detail: ImageDetail? = nil) -> Self {
        .userParts([
            .text(text),
            .imageURL(ChatCompletionImageURL(url: imageURL, detail: detail)),
        ])
    }

    /// Creates a user message with text and a base64-encoded image.
    ///
    /// Usage:
    /// ```swift
    /// let imageData = try Data(contentsOf: imageFileURL)
    /// let message: ChatCompletionMessage = .user(
    ///     text: "What's in this image?",
    ///     imageData: imageData,
    ///     mimeType: .png,
    ///     detail: .high
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - text: The text content of the message.
    ///   - imageData: The raw image data.
    ///   - mimeType: The MIME type of the image.
    ///   - detail: The detail level for image processing. Defaults to `nil`.
    /// - Returns: A `.userParts` message containing a text part and a base64 image part.
    public static func user(text: String, imageData: Data, mimeType: ImageMediaType, detail: ImageDetail? = nil) -> Self {
        .userParts([
            .text(text),
            .imageData(imageData, mimeType: mimeType, detail: detail),
        ])
    }

    /// Creates a user message with multiple content parts.
    ///
    /// Usage:
    /// ```swift
    /// let message: ChatCompletionMessage = .user(parts: [
    ///     .text("Compare these images:"),
    ///     .imageURL(ChatCompletionImageURL(url: "https://example.com/a.png")),
    ///     .imageURL(ChatCompletionImageURL(url: "https://example.com/b.png")),
    /// ])
    /// ```
    /// - Parameter parts: An array of content parts composing the message.
    /// - Returns: A `.userParts` message containing the given parts.
    public static func user(parts: [ChatCompletionContentPart]) -> Self {
        .userParts(parts)
    }
}

/// A tool call made by the assistant.
public struct ChatCompletionToolCall: Codable, Sendable {
    public let id: String
    public let type: String
    public let function: FunctionCall

    public init(id: String, type: String = "function", function: FunctionCall) {
        self.id = id
        self.type = type
        self.function = function
    }
}

/// A function call within a tool call.
public struct FunctionCall: Codable, Sendable {
    public let name: String
    public let arguments: String

    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }
}
