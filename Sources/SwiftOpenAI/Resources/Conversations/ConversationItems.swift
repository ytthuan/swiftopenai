import Foundation

/// Access conversation items within a conversation.
///
/// Items represent messages, tool calls, and other content in a conversation's context.
///
/// Usage:
/// ```swift
/// // Add items to a conversation
/// try await client.conversations.items.create(
///     conversationId: "conv_123",
///     items: [.user("Hello!")]
/// )
///
/// // List items in a conversation
/// let items = try await client.conversations.items.list(conversationId: "conv_123")
/// ```
public struct ConversationItems: Sendable {

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    // MARK: - Create

    /// Adds items to a conversation.
    ///
    /// You may add up to 20 items at a time.
    ///
    /// - Parameters:
    ///   - conversationId: The conversation ID.
    ///   - items: The items to add.
    /// - Returns: A ``ConversationItemList`` of the created items.
    public func create(
        conversationId: String,
        items: [ConversationInputItem]
    ) async throws -> ConversationItemList {
        let validatedConversationID = try conversationId.validatePathComponent()
        let params = ConversationItemsCreateParams(items: items)
        return try await client.post(
            path: "conversations/\(validatedConversationID)/items",
            body: params
        )
    }

    // MARK: - List

    /// Lists items in a conversation.
    ///
    /// - Parameters:
    ///   - conversationId: The conversation ID.
    ///   - after: A cursor for forward pagination.
    ///   - before: A cursor for backward pagination.
    ///   - limit: Maximum number of items to return (default: 20).
    ///   - order: Sort order — `"asc"` or `"desc"` (default: `"asc"`).
    /// - Returns: A ``ConversationItemList``.
    public func list(
        conversationId: String,
        after: String? = nil,
        before: String? = nil,
        limit: Int? = nil,
        order: String? = nil
    ) async throws -> ConversationItemList {
        let validatedConversationID = try conversationId.validatePathComponent()
        var queryItems: [URLQueryItem] = []
        if let after { queryItems.append(URLQueryItem(name: "after", value: after)) }
        if let before { queryItems.append(URLQueryItem(name: "before", value: before)) }
        if let limit { queryItems.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let order { queryItems.append(URLQueryItem(name: "order", value: order)) }
        return try await client.get(
            path: "conversations/\(validatedConversationID)/items",
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
    }

    // MARK: - Retrieve

    /// Retrieves a conversation item by ID.
    ///
    /// - Parameters:
    ///   - itemId: The conversation item ID.
    ///   - conversationId: The conversation ID.
    /// - Returns: The ``ConversationItem``.
    public func retrieve(_ itemId: String, conversationId: String) async throws -> ConversationItem {
        let validatedConversationID = try conversationId.validatePathComponent()
        let validatedItemID = try itemId.validatePathComponent()
        return try await client.get(path: "conversations/\(validatedConversationID)/items/\(validatedItemID)")
    }

    // MARK: - Delete

    /// Deletes a conversation item by ID.
    ///
    /// - Parameters:
    ///   - itemId: The conversation item ID.
    ///   - conversationId: The conversation ID.
    /// - Returns: The updated ``Conversation``.
    public func delete(_ itemId: String, conversationId: String) async throws -> Conversation {
        let validatedConversationID = try conversationId.validatePathComponent()
        let validatedItemID = try itemId.validatePathComponent()
        return try await client.delete(path: "conversations/\(validatedConversationID)/items/\(validatedItemID)")
    }
}
