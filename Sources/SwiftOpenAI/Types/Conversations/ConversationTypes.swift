import Foundation

// MARK: - Conversation

/// A conversation object from the Conversations API.
public struct Conversation: Codable, Sendable, Identifiable {
    /// The unique ID of the conversation.
    public let id: String
    /// The object type, always `"conversation"`.
    public let object: String
    /// The Unix timestamp (in seconds) of when the conversation was created.
    public let createdAt: Int
    /// Key-value metadata attached to the conversation.
    public let metadata: [String: String]?
}

/// Response when deleting a conversation.
public struct ConversationDeleted: Codable, Sendable {
    /// The conversation ID that was deleted.
    public let id: String
    /// Whether the deletion was successful.
    public let deleted: Bool
    /// The object type, always `"conversation.deleted"`.
    public let object: String
}

// MARK: - Conversation Items

/// A paginated list of conversation items.
public struct ConversationItemList: Codable, Sendable {
    /// The object type, always `"list"`.
    public let object: String
    /// The list of conversation items.
    public let data: [ConversationItem]
    /// Whether there are more items available.
    public let hasMore: Bool
    /// The ID of the first item in the list.
    public let firstId: String?
    /// The ID of the last item in the list.
    public let lastId: String?
}

/// A single item in a conversation.
///
/// Items can be messages, tool calls, tool outputs, reasoning items, etc.
/// The `type` field indicates the kind of item.
public struct ConversationItem: Codable, Sendable {
    /// The unique ID of the item.
    public let id: String?
    /// The type of the item (e.g. `"message"`, `"function_call"`, `"function_call_output"`).
    public let type: String
    /// The role of the message author (for message items).
    public let role: String?
    /// The status of the item (e.g. `"completed"`, `"in_progress"`, `"incomplete"`).
    public let status: String?
    /// The content parts of a message item.
    public let content: [ConversationItemContent]?
    /// The name of a function call.
    public let name: String?
    /// The arguments of a function call (JSON string).
    public let arguments: String?
    /// The call ID for function calls and outputs.
    public let callId: String?
    /// The output of a function call (for `function_call_output` items).
    public let output: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case role
        case status
        case content
        case name
        case arguments
        case callId = "call_id"
        case output
    }
}

/// Content part of a conversation item.
public struct ConversationItemContent: Codable, Sendable {
    /// The type of content (e.g. `"input_text"`, `"output_text"`, `"refusal"`).
    public let type: String
    /// The text content.
    public let text: String?
    /// The refusal text (for refusal content).
    public let refusal: String?
}

// MARK: - Input Types

/// An input item for creating conversation items.
///
/// Uses the "easy input message" format for simplicity.
public struct ConversationInputItem: Encodable, Sendable {
    /// The role of the message author (`"user"`, `"assistant"`, `"system"`, `"developer"`).
    public let role: String
    /// The text content of the message.
    public let content: String
    /// The type of the item. Defaults to `"message"`.
    public let type: String?

    /// Creates a new conversation input item.
    ///
    /// - Parameters:
    ///   - role: The role of the message author.
    ///   - content: The text content.
    ///   - type: The item type (default: `"message"`).
    public init(role: String, content: String, type: String? = "message") {
        self.role = role
        self.content = content
        self.type = type
    }

    /// Creates a user message.
    public static func user(_ content: String) -> ConversationInputItem {
        ConversationInputItem(role: "user", content: content)
    }

    /// Creates a system message.
    public static func system(_ content: String) -> ConversationInputItem {
        ConversationInputItem(role: "system", content: content)
    }

    /// Creates a developer message.
    public static func developer(_ content: String) -> ConversationInputItem {
        ConversationInputItem(role: "developer", content: content)
    }

    /// Creates an assistant message.
    public static func assistant(_ content: String) -> ConversationInputItem {
        ConversationInputItem(role: "assistant", content: content)
    }
}

// MARK: - Request Params

/// Parameters for creating a conversation.
struct ConversationCreateParams: Encodable, Sendable {
    let items: [ConversationInputItem]?
    let metadata: [String: String]?
}

/// Parameters for updating a conversation.
struct ConversationUpdateParams: Encodable, Sendable {
    let metadata: [String: String]
}

/// Parameters for adding items to a conversation.
struct ConversationItemsCreateParams: Encodable, Sendable {
    let items: [ConversationInputItem]
}
