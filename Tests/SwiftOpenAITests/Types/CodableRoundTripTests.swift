import Testing
import Foundation
@testable import SwiftOpenAI

/// Codable round-trip tests for CompletionTypes.swift types.
@Suite struct CompletionTypeCodableTests {

    @Test func decodesCompletionWithLogprobs() throws {
        let json = """
        {
            "id": "cmpl-logp",
            "object": "text_completion",
            "created": 1700000000,
            "model": "gpt-3.5-turbo-instruct",
            "choices": [
                {
                    "index": 0,
                    "text": " world!",
                    "logprobs": {
                        "tokens": ["world", "!"],
                        "token_logprobs": [-0.5, -0.1],
                        "top_logprobs": [{"world": -0.5, "earth": -1.2}, {"!": -0.1}],
                        "text_offset": [6, 11]
                    },
                    "finish_reason": "stop"
                }
            ],
            "usage": {
                "prompt_tokens": 5,
                "completion_tokens": 2,
                "total_tokens": 7
            },
            "system_fingerprint": "fp_abc"
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let completion = try decoder.decode(Completion.self, from: json.data(using: .utf8)!)

        #expect(completion.id == "cmpl-logp")
        #expect(completion.choices[0].logprobs?.tokens == ["world", "!"])
        #expect(completion.choices[0].logprobs?.tokenLogprobs == [-0.5, -0.1])
        #expect(completion.choices[0].logprobs?.textOffset == [6, 11])
        #expect(completion.systemFingerprint == "fp_abc")
    }

    @Test func decodesCompletionChunk() throws {
        let json = """
        {
            "id": "cmpl-chunk",
            "object": "text_completion.chunk",
            "created": 1700000001,
            "model": "gpt-3.5-turbo-instruct",
            "choices": [
                {"index": 0, "text": "Hello", "finish_reason": null},
                {"index": 1, "text": " there", "finish_reason": "stop"}
            ]
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let chunk = try decoder.decode(CompletionChunk.self, from: json.data(using: .utf8)!)

        #expect(chunk.id == "cmpl-chunk")
        #expect(chunk.choices.count == 2)
        #expect(chunk.choices[0].text == "Hello")
        #expect(chunk.choices[0].finishReason == nil)
        #expect(chunk.choices[1].text == " there")
        #expect(chunk.choices[1].finishReason == "stop")
    }

    @Test func encodesCompletionPromptString() throws {
        let prompt = CompletionPrompt.string("Hello")
        let data = try JSONEncoder().encode(prompt)
        let str = String(data: data, encoding: .utf8)!
        #expect(str == "\"Hello\"")
    }

    @Test func encodesCompletionPromptStrings() throws {
        let prompt = CompletionPrompt.strings(["Hello", "World"])
        let data = try JSONEncoder().encode(prompt)
        let str = String(data: data, encoding: .utf8)!
        #expect(str == "[\"Hello\",\"World\"]")
    }

    @Test func encodesCompletionStopString() throws {
        let stop = CompletionStop.string("\n")
        let data = try JSONEncoder().encode(stop)
        let str = String(data: data, encoding: .utf8)!
        #expect(str == "\"\\n\"")
    }

    @Test func encodesCompletionStopStrings() throws {
        let stop = CompletionStop.strings(["\n", "END"])
        let data = try JSONEncoder().encode(stop)
        let str = String(data: data, encoding: .utf8)!
        #expect(str.contains("\\n"))
        #expect(str.contains("END"))
    }
}

/// Codable round-trip tests for EmbeddingTypes.swift types.
@Suite struct EmbeddingTypeCodableTests {

    @Test func decodesEmbeddingValueAsFloats() throws {
        let json = "[0.1, 0.2, 0.3]"
        let value = try JSONDecoder().decode(EmbeddingValue.self, from: json.data(using: .utf8)!)
        if case .floats(let arr) = value {
            #expect(arr.count == 3)
            #expect(arr[0] == 0.1)
        } else {
            #expect(Bool(false), "Expected .floats case")
        }
    }

    @Test func decodesEmbeddingValueAsBase64() throws {
        let json = "\"SGVsbG8=\""
        let value = try JSONDecoder().decode(EmbeddingValue.self, from: json.data(using: .utf8)!)
        if case .base64(let str) = value {
            #expect(str == "SGVsbG8=")
        } else {
            #expect(Bool(false), "Expected .base64 case")
        }
    }

    @Test func encodesEmbeddingValueFloats() throws {
        let value = EmbeddingValue.floats([1.0, 2.0])
        let data = try JSONEncoder().encode(value)
        let str = String(data: data, encoding: .utf8)!
        #expect(str.contains("1"))
        #expect(str.contains("2"))
    }

    @Test func encodesEmbeddingValueBase64() throws {
        let value = EmbeddingValue.base64("dGVzdA==")
        let data = try JSONEncoder().encode(value)
        let str = String(data: data, encoding: .utf8)!
        #expect(str.contains("dGVzdA=="))
    }

    @Test func decodesFullEmbeddingResponse() throws {
        let json = """
        {
            "object": "list",
            "data": [
                {"object": "embedding", "embedding": [0.1, 0.2], "index": 0},
                {"object": "embedding", "embedding": "YWJj", "index": 1}
            ],
            "model": "text-embedding-3-small",
            "usage": {"prompt_tokens": 8, "total_tokens": 8}
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(CreateEmbeddingResponse.self, from: json.data(using: .utf8)!)

        #expect(response.object == "list")
        #expect(response.data.count == 2)
        #expect(response.model == "text-embedding-3-small")
        #expect(response.usage.promptTokens == 8)
        #expect(response.usage.totalTokens == 8)

        if case .floats(let arr) = response.data[0].embedding {
            #expect(arr == [0.1, 0.2])
        } else {
            #expect(Bool(false), "Expected floats for first embedding")
        }

        if case .base64(let str) = response.data[1].embedding {
            #expect(str == "YWJj")
        } else {
            #expect(Bool(false), "Expected base64 for second embedding")
        }
    }

    @Test func encodesEmbeddingInput() throws {
        let single = EmbeddingInput.string("hello")
        let singleData = try JSONEncoder().encode(single)
        #expect(String(data: singleData, encoding: .utf8) == "\"hello\"")

        let multi = EmbeddingInput.strings(["a", "b"])
        let multiData = try JSONEncoder().encode(multi)
        #expect(String(data: multiData, encoding: .utf8) == "[\"a\",\"b\"]")
    }

    @Test func embeddingValueRejectsInvalidInput() throws {
        let json = "true" // Not an array or string
        do {
            _ = try JSONDecoder().decode(EmbeddingValue.self, from: json.data(using: .utf8)!)
            #expect(Bool(false), "Should have thrown")
        } catch is DecodingError {
            // Expected
        }
    }
}
