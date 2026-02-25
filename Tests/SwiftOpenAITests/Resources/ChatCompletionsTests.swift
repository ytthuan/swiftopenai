import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SwiftOpenAI

// MARK: - Chat Completions Tests

extension MockAPITests {

    @Test func createChatCompletion() async throws {
        let json = """
        {
            "id": "chatcmpl-123",
            "object": "chat.completion",
            "created": 1234567890,
            "model": "gpt-4o",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": "Hello!"
                },
                "finish_reason": "stop"
            }],
            "usage": {
                "prompt_tokens": 10,
                "completion_tokens": 5,
                "total_tokens": 15
            },
            "system_fingerprint": "fp_abc123"
        }
        """
        let client = makeMockClient(json: json)
        let response = try await client.chat.completions.create(
            model: "gpt-4o",
            messages: [.user("Hello!")]
        )

        #expect(response.id == "chatcmpl-123")
        #expect(response.object == "chat.completion")
        #expect(response.model == "gpt-4o")
        #expect(response.choices.count == 1)
        #expect(response.choices[0].message.role == "assistant")
        #expect(response.choices[0].message.content == "Hello!")
        #expect(response.choices[0].finishReason == "stop")
        #expect(response.usage?.promptTokens == 10)
        #expect(response.usage?.completionTokens == 5)
        #expect(response.usage?.totalTokens == 15)
        #expect(response.systemFingerprint == "fp_abc123")
    }

    @Test func createChatCompletionWithToolCalls() async throws {
        let json = """
        {
            "id": "chatcmpl-456",
            "object": "chat.completion",
            "created": 1234567890,
            "model": "gpt-4o",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": null,
                    "tool_calls": [{
                        "id": "call_abc123",
                        "type": "function",
                        "function": {
                            "name": "get_weather",
                            "arguments": "{\\"location\\":\\"Paris\\"}"
                        }
                    }]
                },
                "finish_reason": "tool_calls"
            }],
            "usage": {
                "prompt_tokens": 20,
                "completion_tokens": 10,
                "total_tokens": 30
            }
        }
        """
        let client = makeMockClient(json: json)
        let response = try await client.chat.completions.create(
            model: "gpt-4o",
            messages: [.user("What's the weather in Paris?")]
        )

        #expect(response.id == "chatcmpl-456")
        #expect(response.choices.count == 1)
        #expect(response.choices[0].message.content == nil)
        #expect(response.choices[0].finishReason == "tool_calls")

        let toolCalls = try #require(response.choices[0].message.toolCalls)
        #expect(toolCalls.count == 1)
        #expect(toolCalls[0].id == "call_abc123")
        #expect(toolCalls[0].type == "function")
        #expect(toolCalls[0].function.name == "get_weather")
        #expect(toolCalls[0].function.arguments == "{\"location\":\"Paris\"}")
    }

    @Test func createChatCompletionStream() async throws {
        let json = """
        data: {"id":"chatcmpl-stream-1","object":"chat.completion.chunk","created":1234567890,"model":"gpt-4o","choices":[{"index":0,"delta":{"role":"assistant","content":"Hello"},"finish_reason":null}]}

        data: {"id":"chatcmpl-stream-1","object":"chat.completion.chunk","created":1234567890,"model":"gpt-4o","choices":[{"index":0,"delta":{"content":" world"},"finish_reason":"stop"}]}

        data: [DONE]

        """
        let client = makeMockClient(json: json)
        let stream = try await client.chat.completions.createStream(
            model: "gpt-4o",
            messages: [.user("Hello!")]
        )

        var chunks: [ChatCompletionChunk] = []
        for try await chunk in stream {
            chunks.append(chunk)
        }

        #expect(chunks.count == 2)

        let first = chunks[0]
        #expect(first.id == "chatcmpl-stream-1")
        #expect(first.object == "chat.completion.chunk")
        #expect(first.model == "gpt-4o")
        #expect(first.choices[0].delta?.content == "Hello")
        #expect(first.choices[0].finishReason == nil)

        let second = chunks[1]
        #expect(second.id == "chatcmpl-stream-1")
        #expect(second.object == "chat.completion.chunk")
        #expect(second.model == "gpt-4o")
        #expect(second.choices[0].delta?.content == " world")
        #expect(second.choices[0].finishReason == "stop")
    }
}
