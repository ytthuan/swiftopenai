import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
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
        let json = #"{"id": "resp-789", "object": "response.deleted", "deleted": true}"#
        let client = makeMockClient(json: json)
        let response = try await client.responses.delete("resp-789")

        #expect(response.id == "resp-789")
        #expect(response.object == "response.deleted")
        #expect(response.deleted == true)
    }

    @Test func createResponseWithFunctionCall() async throws {
        let json = """
        {
            "id": "resp-fc-123",
            "object": "response",
            "created_at": 1234567890,
            "model": "gpt-4o",
            "output": [{
                "type": "function_call",
                "id": "fc-123",
                "call_id": "call_123",
                "name": "get_weather",
                "arguments": "{\\"location\\":\\"Paris\\"}",
                "status": "completed"
            }],
            "status": "completed"
        }
        """
        let client = makeMockClient(json: json)
        let response = try await client.responses.create(
            model: "gpt-4o",
            input: .text("What's the weather in Paris?"),
            tools: [.function(FunctionToolDefinition(name: "get_weather"))]
        )

        #expect(response.id == "resp-fc-123")
        #expect(response.output.count == 1)
        #expect(response.output[0].type == "function_call")
        #expect(response.output[0].callId == "call_123")
        #expect(response.output[0].name == "get_weather")
        #expect(response.output[0].arguments == "{\"location\":\"Paris\"}")

        let requestBody = MockURLProtocol.lastRequestBody
        let bodyJSON = try #require(requestBody.flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
        })
        let tools = try #require(bodyJSON["tools"] as? [[String: Any]])
        #expect(tools.count == 1)
        #expect(tools[0]["type"] as? String == "function")
        #expect(tools[0]["name"] as? String == "get_weather")
    }

    @Test func createResponseWithToolChoice() async throws {
        let json = """
        {
            "id": "resp-tool-choice",
            "object": "response",
            "created_at": 1234567890,
            "model": "gpt-4o",
            "output": [],
            "status": "completed"
        }
        """
        let client = makeMockClient(json: json)
        _ = try await client.responses.create(
            model: "gpt-4o",
            input: .text("Use the weather tool"),
            tools: [.function(FunctionToolDefinition(name: "get_weather"))],
            toolChoice: .function("get_weather")
        )

        let requestBody = MockURLProtocol.lastRequestBody
        let bodyJSON = try #require(requestBody.flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
        })
        let toolChoice = try #require(bodyJSON["tool_choice"] as? [String: Any])
        #expect(toolChoice["type"] as? String == "function")
        #expect(toolChoice["name"] as? String == "get_weather")
    }

    @Test func createResponseWithStructuredOutput() async throws {
        let json = """
        {
            "id": "resp-structured-123",
            "object": "response",
            "created_at": 1234567890,
            "model": "gpt-4o",
            "output": [{
                "type": "message",
                "id": "msg-structured",
                "role": "assistant",
                "content": [{"type": "output_text", "text": "{\\"answer\\":42}"}]
            }],
            "status": "completed"
        }
        """
        let client = makeMockClient(json: json)
        let response = try await client.responses.create(
            model: "gpt-4o",
            input: .text("Return structured JSON"),
            text: ResponseTextConfig(
                format: .jsonSchema(
                    ResponseTextFormatJSONSchema(
                        name: "math_answer",
                        schema: ["type": AnyCodable("object")]
                    )
                )
            )
        )

        #expect(response.id == "resp-structured-123")
        #expect(response.output[0].content?[0].text == "{\"answer\":42}")

        let requestBody = MockURLProtocol.lastRequestBody
        let bodyJSON = try #require(requestBody.flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
        })
        let text = try #require(bodyJSON["text"] as? [String: Any])
        let format = try #require(text["format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
        #expect(format["name"] as? String == "math_answer")
        let schema = try #require(format["schema"] as? [String: Any])
        #expect(schema["type"] as? String == "object")
    }

    @Test func compactResponse() async throws {
        let json = """
        {
            "id": "resp-compact-123",
            "object": "response.compaction",
            "created_at": 1234567890,
            "output": [{
                "type": "message",
                "id": "msg-compact",
                "role": "assistant",
                "content": [{"type": "output_text", "text": "Compacted summary"}]
            }],
            "usage": {
                "input_tokens": 100,
                "output_tokens": 20,
                "total_tokens": 120
            }
        }
        """
        let client = makeMockClient(json: json)
        let response = try await client.responses.compact(
            model: "gpt-4o-mini",
            input: .text("Long conversation"),
            previousResponseId: "resp-prev-123"
        )

        #expect(response.id == "resp-compact-123")
        #expect(response.object == "response.compaction")
        #expect(response.output[0].content?[0].text == "Compacted summary")
        #expect(response.usage?.totalTokens == 120)

        let requestURL = MockURLProtocol.lastRequest?.url?.absoluteString
        #expect(requestURL?.contains("responses/compact") == true)
    }

    @Test func createResponseWithFunctionCallOutput() async throws {
        let json = """
        {
            "id": "resp-fco-123",
            "object": "response",
            "created_at": 1234567890,
            "model": "gpt-4o",
            "output": [{
                "type": "message",
                "id": "msg-fco",
                "role": "assistant",
                "content": [{"type": "output_text", "text": "The weather in Paris is 22C."}]
            }],
            "status": "completed"
        }
        """
        let client = makeMockClient(json: json)
        let response = try await client.responses.create(
            model: "gpt-4o",
            input: .items([
                .functionCall(
                    FunctionCallItem(
                        callId: "call_456",
                        name: "get_weather",
                        arguments: "{\"location\":\"Paris\"}"
                    )
                ),
                .functionCallOutput(FunctionCallOutput(callId: "call_456", output: "{\"temperature\":22}"))
            ])
        )

        #expect(response.id == "resp-fco-123")
        #expect(response.output[0].content?[0].text == "The weather in Paris is 22C.")

        let requestBody = MockURLProtocol.lastRequestBody
        let bodyJSON = try #require(requestBody.flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
        })
        let inputItems = try #require(bodyJSON["input"] as? [[String: Any]])
        #expect(inputItems.count == 2)
        #expect(inputItems[0]["type"] as? String == "function_call")
        #expect(inputItems[0]["call_id"] as? String == "call_456")
        #expect(inputItems[1]["type"] as? String == "function_call_output")
        #expect(inputItems[1]["call_id"] as? String == "call_456")
    }

    @Test func responseStreamEventParsesTextDelta() throws {
        let json = """
        {
            "type": "response.output_text.delta",
            "delta": "Hel",
            "output_index": 0,
            "content_index": 0
        }
        """
        let event = try HTTPClient.decoder.decode(ResponseStreamEvent.self, from: Data(json.utf8))
        #expect(event.type == "response.output_text.delta")
        #expect(event.delta == "Hel")
        #expect(event.outputIndex == 0)
        #expect(event.contentIndex == 0)
    }

    @Test func responseStreamEventParsesCompleted() throws {
        let json = """
        {
            "type": "response.completed",
            "response": {
                "id": "resp-stream-123",
                "object": "response",
                "created_at": 1234567890,
                "model": "gpt-4o",
                "output": [],
                "status": "completed"
            }
        }
        """
        let event = try HTTPClient.decoder.decode(ResponseStreamEvent.self, from: Data(json.utf8))
        let response = try #require(event.response)
        #expect(event.type == "response.completed")
        #expect(response.id == "resp-stream-123")
        #expect(response.status == "completed")
    }

    @Test func createResponseWithReasoning() async throws {
        let json = """
        {
            "id": "resp-reason-123",
            "object": "response",
            "created_at": 1234567890,
            "model": "o4-mini",
            "output": [{
                "type": "reasoning",
                "id": "rs-123",
                "summary": [{
                    "type": "summary_text",
                    "text": "Need to compare a few options first."
                }]
            }],
            "status": "completed"
        }
        """
        let client = makeMockClient(json: json)
        let response = try await client.responses.create(
            model: "o4-mini",
            input: .text("Solve this carefully"),
            reasoning: ReasoningConfig(effort: "high")
        )

        #expect(response.id == "resp-reason-123")
        #expect(response.output[0].type == "reasoning")
        #expect(response.output[0].summary?[0].text == "Need to compare a few options first.")

        let requestBody = MockURLProtocol.lastRequestBody
        let bodyJSON = try #require(requestBody.flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
        })
        let reasoning = try #require(bodyJSON["reasoning"] as? [String: Any])
        #expect(reasoning["effort"] as? String == "high")
    }
}
