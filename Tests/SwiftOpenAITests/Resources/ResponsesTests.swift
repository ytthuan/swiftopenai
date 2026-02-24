import Testing
import Foundation
@testable import SwiftOpenAI

// MARK: - Tests

extension MockAPITests {

    @Test func createResponse() async throws {
        let json = """
        {
            "id": "resp-123",
            "object": "response",
            "created_at": 1234567890,
            "model": "gpt-4o",
            "output": [{
                "type": "message",
                "id": "msg-123",
                "role": "assistant",
                "content": [{"type": "output_text", "text": "Hello!"}]
            }],
            "status": "completed",
            "usage": {
                "input_tokens": 10,
                "output_tokens": 5,
                "total_tokens": 15
            }
        }
        """
        let client = makeMockClient(json: json)
        let response = try await client.responses.create(
            model: "gpt-4o",
            input: .text("Hello!")
        )

        #expect(response.id == "resp-123")
        #expect(response.object == "response")
        #expect(response.createdAt == 1234567890)
        #expect(response.model == "gpt-4o")
        #expect(response.status == "completed")
        #expect(response.output.count == 1)
        #expect(response.output[0].type == "message")
        #expect(response.output[0].id == "msg-123")
        #expect(response.output[0].role == "assistant")
        #expect(response.output[0].content?.count == 1)
        #expect(response.output[0].content?[0].type == "output_text")
        #expect(response.output[0].content?[0].text == "Hello!")
        #expect(response.usage?.inputTokens == 10)
        #expect(response.usage?.outputTokens == 5)
        #expect(response.usage?.totalTokens == 15)
    }

    @Test func retrieveResponse() async throws {
        let json = """
        {
            "id": "resp-456",
            "object": "response",
            "created_at": 1234567890,
            "model": "gpt-4o",
            "output": [],
            "status": "completed"
        }
        """
        let client = makeMockClient(json: json)
        let response = try await client.responses.retrieve("resp-456")

        #expect(response.id == "resp-456")
        #expect(response.status == "completed")
    }

    @Test func deleteResponse() async throws {
        let json = """
        {
            "id": "resp-789",
            "object": "response",
            "created_at": 1234567890,
            "model": "gpt-4o",
            "output": [],
            "status": "completed"
        }
        """
        let client = makeMockClient(json: json)
        let response = try await client.responses.delete("resp-789")

        #expect(response.id == "resp-789")
    }
}
