import Testing
import Foundation
@testable import SwiftOpenAI

/// Tests for ChatCompletion.swift types — Codable round-trip and memberwise init coverage.
@Suite struct ChatCompletionTypeTests {

    // MARK: - Full round-trip decode → encode → decode

    @Test func decodesFullChatCompletionJSON() throws {
        let json = """
        {
            "id": "chatcmpl-abc123",
            "object": "chat.completion",
            "created": 1700000000,
            "model": "gpt-4o",
            "choices": [
                {
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": "Hello!",
                        "refusal": null
                    },
                    "finish_reason": "stop",
                    "logprobs": null
                }
            ],
            "usage": {
                "prompt_tokens": 10,
                "completion_tokens": 5,
                "total_tokens": 15
            },
            "system_fingerprint": "fp_abc123",
            "service_tier": "default"
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let completion = try decoder.decode(ChatCompletion.self, from: json.data(using: .utf8)!)
        #expect(completion.id == "chatcmpl-abc123")
        #expect(completion.object == "chat.completion")
        #expect(completion.created == 1700000000)
        #expect(completion.model == "gpt-4o")
        #expect(completion.choices.count == 1)
        #expect(completion.choices[0].index == 0)
        #expect(completion.choices[0].message.role == "assistant")
        #expect(completion.choices[0].message.content == "Hello!")
        #expect(completion.choices[0].message.refusal == nil)
        #expect(completion.choices[0].finishReason == "stop")
        #expect(completion.choices[0].logprobs == nil)
        #expect(completion.usage?.promptTokens == 10)
        #expect(completion.usage?.completionTokens == 5)
        #expect(completion.usage?.totalTokens == 15)
        #expect(completion.systemFingerprint == "fp_abc123")
        #expect(completion.serviceTier == "default")
    }

    @Test func decodesMinimalChatCompletion() throws {
        let json = """
        {
            "id": "chatcmpl-min",
            "object": "chat.completion",
            "created": 1700000001,
            "model": "gpt-4o-mini",
            "choices": []
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let completion = try decoder.decode(ChatCompletion.self, from: json.data(using: .utf8)!)
        #expect(completion.id == "chatcmpl-min")
        #expect(completion.choices.isEmpty)
        #expect(completion.usage == nil)
        #expect(completion.systemFingerprint == nil)
        #expect(completion.serviceTier == nil)
    }

    @Test func codableRoundTripPreservesValues() throws {
        let original = ChatCompletion(
            id: "chatcmpl-roundtrip",
            created: 1700000002,
            model: "gpt-4o",
            choices: [
                ChatCompletionChoice(
                    index: 0,
                    message: ChatCompletionResponseMessage(content: "Hi there"),
                    finishReason: "stop"
                )
            ],
            usage: Usage(promptTokens: 3, completionTokens: 2, totalTokens: 5),
            systemFingerprint: "fp_test"
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ChatCompletion.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.object == original.object)
        #expect(decoded.created == original.created)
        #expect(decoded.model == original.model)
        #expect(decoded.choices.count == 1)
        #expect(decoded.choices[0].message.content == "Hi there")
        #expect(decoded.systemFingerprint == "fp_test")
    }

    @Test func decodesToolCallsInMessage() throws {
        let json = """
        {
            "id": "chatcmpl-tools",
            "object": "chat.completion",
            "created": 1700000003,
            "model": "gpt-4o",
            "choices": [
                {
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": null,
                        "tool_calls": [
                            {
                                "id": "call_abc",
                                "type": "function",
                                "function": {
                                    "name": "get_weather",
                                    "arguments": "{\\"city\\":\\"SF\\"}"
                                }
                            }
                        ]
                    },
                    "finish_reason": "tool_calls"
                }
            ]
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let completion = try decoder.decode(ChatCompletion.self, from: json.data(using: .utf8)!)
        let message = completion.choices[0].message
        #expect(message.content == nil)
        #expect(message.toolCalls?.count == 1)
        #expect(message.toolCalls?[0].id == "call_abc")
        #expect(message.toolCalls?[0].function.name == "get_weather")
    }

    @Test func decodesLogprobsInChoice() throws {
        let json = """
        {
            "id": "chatcmpl-lp",
            "object": "chat.completion",
            "created": 1700000004,
            "model": "gpt-4o",
            "choices": [
                {
                    "index": 0,
                    "message": {"role": "assistant", "content": "Hi"},
                    "finish_reason": "stop",
                    "logprobs": {
                        "content": [
                            {"token": "Hi", "logprob": -0.5, "bytes": [72, 105]}
                        ]
                    }
                }
            ]
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let completion = try decoder.decode(ChatCompletion.self, from: json.data(using: .utf8)!)
        let logprobs = completion.choices[0].logprobs
        #expect(logprobs != nil)
        #expect(logprobs?.content?.count == 1)
        #expect(logprobs?.content?[0].token == "Hi")
        #expect(logprobs?.content?[0].logprob == -0.5)
        #expect(logprobs?.content?[0].bytes == [72, 105])
    }

    @Test func decodesRefusalInMessage() throws {
        let json = """
        {
            "id": "chatcmpl-refuse",
            "object": "chat.completion",
            "created": 1700000005,
            "model": "gpt-4o",
            "choices": [
                {
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": null,
                        "refusal": "I cannot help with that."
                    },
                    "finish_reason": "stop"
                }
            ]
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let completion = try decoder.decode(ChatCompletion.self, from: json.data(using: .utf8)!)
        let message = completion.choices[0].message
        #expect(message.content == nil)
        #expect(message.refusal == "I cannot help with that.")
    }
}
