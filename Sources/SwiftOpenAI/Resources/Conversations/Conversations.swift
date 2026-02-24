import Foundation

/// Access the OpenAI Conversations API.
///
/// Conversations provide server-managed conversation state for multi-turn
/// interactions. Use with the Responses API via `previousResponseId` or manage
/// items directly.
///
/// Usage:
/// ```swift
/// let conversation = try await client.conversations.create()
/// let items = try await client.conversations.items.list(conversationId: conversation.id)
/// ```
public struct Conversations: Sendable {

    private let client: HTTPClient

    /// Access conversation items.
    public let items: ConversationItems

    init(client: HTTPClient) {
        self.client = client
        self.items = ConversationItems(client: client)
    }

    // MARK: - Create

    /// Creates a new conversation.
    ///
    /// - Parameters:
    ///   - items: Optional initial items to include in the conversation context (up to 20).
    ///   - metadata: Optional key-value metadata to attach.
    /// - Returns: The created ``Conversation``.
    public func create(
        items: [ConversationInputItem]? = nil,
        metadata: [String: String]? = nil
    ) async throws -> Conversation {
        let params = ConversationCreateParams(items: items, metadata: metadata)
        return try await client.post(path: "conversations", body: params)
    }

    // MARK: - Retrieve

    /// Retrieves a conversation by ID.
    ///
    /// - Parameter id: The conversation ID.
    /// - Returns: The ``Conversation``.
    public func retrieve(_ id: String) async throws -> Conversation {
        let validatedID = try id.validatePathComponent()
        return try await client.get(path: "conversations/\(validatedID)")
    }

    // MARK: - Update

    /// Updates a conversation's metadata.
    ///
    /// - Parameters:
    ///   - id: The conversation ID.
    ///   - metadata: New key-value metadata to set.
    /// - Returns: The updated ``Conversation``.
    public func update(_ id: String, metadata: [String: String]) async throws -> Conversation {
        let validatedID = try id.validatePathComponent()
        let params = ConversationUpdateParams(metadata: metadata)
        return try await client.post(path: "conversations/\(validatedID)", body: params)
    }

    // MARK: - Delete

    /// Deletes a conversation. Items in the conversation will not be deleted.
    ///
    /// - Parameter id: The conversation ID.
    /// - Returns: A ``ConversationDeleted`` confirmation.
    public func delete(_ id: String) async throws -> ConversationDeleted {
        let validatedID = try id.validatePathComponent()
        return try await client.delete(path: "conversations/\(validatedID)")
    }
}
