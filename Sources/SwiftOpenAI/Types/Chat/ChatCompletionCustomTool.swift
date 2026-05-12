import Foundation

/// A custom tool definition for chat completions.
///
/// Custom tools allow defining non-function tools with user-specified
/// output formats, including text and grammar-based formats.
///
/// Wire format:
/// ```json
/// {
///   "name": "my_tool",
///   "description": "A custom tool",
///   "format": {"type": "text"}
/// }
/// ```
public struct ChatCompletionCustomTool: Encodable, Sendable {
    /// The name of the custom tool.
    public var name: String
    /// A description of what the custom tool does.
    public var description: String?
    /// The output format for the custom tool.
    public var format: Format?

    public init(name: String, description: String? = nil, format: Format? = nil) {
        self.name = name
        self.description = description
        self.format = format
    }

    // MARK: - Format

    /// Output format for a custom tool.
    ///
    /// Wire format:
    /// - `.text` → `{"type":"text"}`
    /// - `.grammar(...)` → `{"type":"grammar","grammar":{"definition":"...","syntax":"lark"}}`
    public enum Format: Encodable, Sendable {
        /// Plain text output.
        case text
        /// Grammar-based structured output.
        case grammar(definition: String, syntax: GrammarSyntax)

        /// Syntax type for grammar-based format.
        public enum GrammarSyntax: String, Encodable, Sendable {
            case lark
            case regex
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .text:
                try container.encode("text", forKey: .type)
            case .grammar(let definition, let syntax):
                try container.encode("grammar", forKey: .type)
                var grammarContainer = container.nestedContainer(
                    keyedBy: GrammarCodingKeys.self, forKey: .grammar
                )
                try grammarContainer.encode(definition, forKey: .definition)
                try grammarContainer.encode(syntax, forKey: .syntax)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type, grammar
        }

        private enum GrammarCodingKeys: String, CodingKey {
            case definition, syntax
        }
    }
}
