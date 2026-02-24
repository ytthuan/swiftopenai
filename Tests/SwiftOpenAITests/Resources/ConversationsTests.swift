import Testing
import Foundation
@testable import SwiftOpenAI

// MARK: - Conversations Tests

extension MockAPITests {

    @Test func createConversation() async throws {
        let json = """
        {
            "id": "conv_123",
            "object": "conversation",
            "created_at": 1234567890,
            "metadata": {"project": "test"}
        }
        """
        let client = makeMockClient(json: json)
        let conversation = try await client.conversations.create(
            metadata: ["project": "test"]
        )

        #expect(conversation.id == "conv_123")
        #expect(conversation.object == "conversation")
        #expect(conversation.createdAt == 1234567890)
        #expect(conversation.metadata?["project"] == "test")
    }

    @Test func retrieveConversation() async throws {
        let json = """
        {
            "id": "conv_456",
            "object": "conversation",
            "created_at": 1234567890,
            "metadata": null
        }
        """
        let client = makeMockClient(json: json)
        let conversation = try await client.conversations.retrieve("conv_456")

        #expect(conversation.id == "conv_456")
        #expect(conversation.object == "conversation")

        let requestURL = MockURLProtocol.lastRequest?.url?.absoluteString
        #expect(requestURL?.contains("conversations/conv_456") == true)
    }

    @Test func updateConversation() async throws {
        let json = """
        {
            "id": "conv_789",
            "object": "conversation",
            "created_at": 1234567890,
            "metadata": {"updated": "true"}
        }
        """
        let client = makeMockClient(json: json)
        let conversation = try await client.conversations.update(
            "conv_789",
            metadata: ["updated": "true"]
        )

        #expect(conversation.id == "conv_789")
        #expect(conversation.metadata?["updated"] == "true")

        let requestURL = MockURLProtocol.lastRequest?.url?.absoluteString
        #expect(requestURL?.contains("conversations/conv_789") == true)
    }

    @Test func deleteConversation() async throws {
        let json = """
        {
            "id": "conv_123",
            "object": "conversation.deleted",
            "deleted": true
        }
        """
        let client = makeMockClient(json: json)
        let result = try await client.conversations.delete("conv_123")

        #expect(result.id == "conv_123")
        #expect(result.deleted == true)
        #expect(result.object == "conversation.deleted")
    }

    @Test func listConversationItems() async throws {
        let json = """
        {
            "object": "list",
            "data": [
                {
                    "id": "msg_001",
                    "type": "message",
                    "role": "user",
                    "status": "completed",
                    "content": [
                        {
                            "type": "input_text",
                            "text": "Hello!"
                        }
                    ]
                },
                {
                    "id": "msg_002",
                    "type": "message",
                    "role": "assistant",
                    "status": "completed",
                    "content": [
                        {
                            "type": "output_text",
                            "text": "Hi there!"
                        }
                    ]
                }
            ],
            "has_more": false,
            "first_id": "msg_001",
            "last_id": "msg_002"
        }
        """
        let client = makeMockClient(json: json)
        let items = try await client.conversations.items.list(conversationId: "conv_123")

        #expect(items.object == "list")
        #expect(items.data.count == 2)
        #expect(items.hasMore == false)
        #expect(items.firstId == "msg_001")
        #expect(items.lastId == "msg_002")

        #expect(items.data[0].id == "msg_001")
        #expect(items.data[0].type == "message")
        #expect(items.data[0].role == "user")
        #expect(items.data[0].content?.first?.text == "Hello!")

        #expect(items.data[1].role == "assistant")
        #expect(items.data[1].content?.first?.text == "Hi there!")
    }

    @Test func createConversationItems() async throws {
        let json = """
        {
            "object": "list",
            "data": [
                {
                    "id": "msg_003",
                    "type": "message",
                    "role": "user",
                    "status": "completed",
                    "content": [
                        {
                            "type": "input_text",
                            "text": "What is Swift?"
                        }
                    ]
                }
            ],
            "has_more": false,
            "first_id": "msg_003",
            "last_id": "msg_003"
        }
        """
        let client = makeMockClient(json: json)
        let result = try await client.conversations.items.create(
            conversationId: "conv_123",
            items: [.user("What is Swift?")]
        )

        #expect(result.data.count == 1)
        #expect(result.data[0].role == "user")
        #expect(result.data[0].content?.first?.text == "What is Swift?")

        let requestURL = MockURLProtocol.lastRequest?.url?.absoluteString
        #expect(requestURL?.contains("conversations/conv_123/items") == true)
    }

    @Test func createConversationWithInitialItems() async throws {
        let json = """
        {
            "id": "conv_with_items",
            "object": "conversation",
            "created_at": 1234567890,
            "metadata": null
        }
        """
        let client = makeMockClient(json: json)
        let conversation = try await client.conversations.create(
            items: [
                .system("You are a helpful assistant."),
                .user("Hello!")
            ]
        )

        #expect(conversation.id == "conv_with_items")

        // Verify request body contains items
        if let body = MockURLProtocol.lastRequestBody,
           let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
           let items = json["items"] as? [[String: Any]] {
            #expect(items.count == 2)
            #expect(items[0]["role"] as? String == "system")
            #expect(items[1]["role"] as? String == "user")
        }
    }
}
