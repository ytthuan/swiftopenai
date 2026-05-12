import Foundation

/// Predicted output content for chat completions.
///
/// Allows providing expected output content to reduce latency
/// when the model's response is partially known ahead of time.
///
/// Usage:
/// ```swift
/// let prediction = ChatCompletionPredictionContent(
///     content: .text("Expected output text")
/// )
/// ```
public struct ChatCompletionPredictionContent: Encodable, Sendable {
    /// The type discriminator. Always `"content"`.
    public let type: String
    /// The predicted content.
    public var content: Content

    public init(content: Content) {
        self.type = "content"
        self.content = content
    }

    private enum CodingKeys: String, CodingKey {
        case type, content
    }

    // MARK: - Content

    /// The content of a prediction — either a plain string or an array of text parts.
    public enum Content: Encodable, Sendable {
        /// A single text string.
        case text(String)
        /// An array of text content parts.
        case parts([TextPart])

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let string):
                try container.encode(string)
            case .parts(let parts):
                try container.encode(parts)
            }
        }

        /// A text content part within a prediction.
        public struct TextPart: Encodable, Sendable {
            /// The type discriminator. Always `"text"`.
            public let type: String
            /// The text content.
            public var text: String

            public init(text: String) {
                self.type = "text"
                self.text = text
            }

            private enum CodingKeys: String, CodingKey {
                case type, text
            }
        }
    }
}
