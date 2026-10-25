import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SwiftOpenAI

// MARK: - Chat Completions Tests

extension MockAPITests {

    @Test func finalRequestEncoderSortsKeys() {
        #expect(HTTPClient.encoder.outputFormatting.contains(.sortedKeys))
    }

    @Test(arguments: [false, true])
    func deterministicChatRequestBytes(streaming: Bool) async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let client = makeMockClient(json: deterministicChatFixture(streaming: streaming))
        let tools = deterministicTools()
        let baseline = try await sendDeterministicChat(client, tools: tools, streaming: streaming)

        // Compare captured bytes directly: never normalize the bodies under test.
        // Exercise reuse, reconstruction (including opposite insertion order), and client lifetime.
        for iteration in 0..<12 {
            let reused = try await sendDeterministicChat(client, tools: tools, streaming: streaming)
            #expect(reused == baseline)
            let reconstructed = deterministicTools(reverseInsertion: iteration.isMultiple(of: 2))
            let rebuilt = try await sendDeterministicChat(client, tools: reconstructed, streaming: streaming)
            #expect(rebuilt == baseline)
            let freshClient = makeMockClient(json: deterministicChatFixture(streaming: streaming))
            let fresh = try await sendDeterministicChat(freshClient, tools: reconstructed, streaming: streaming)
            #expect(fresh == baseline)
        }
        #expect(MockURLProtocol.requestCount == 37)

        // Independently written wire oracle checks recursive object ordering and unchanged arrays.
        let schema = #"{"additionalProperties":false,"properties":{"alpha":{"enum":["zulu","alpha"],"type":"string"},"zeta":{"properties":{"alpha":{"type":"boolean"},"zeta":{"type":"number"}},"required":["zeta","alpha"],"type":"object"}},"required":["zeta","alpha"],"type":"object"}"#
        let tool = { (name: String) in
            #"{"function":{"description":"Unchanged description","name":""# + name
                + #"","parameters":"# + schema + #","strict":true},"type":"function"}"#
        }
        let streamFields = streaming ? #","stream":true,"stream_options":{"include_usage":true}"# : ""
        let expected = #"{"max_completion_tokens":64,"messages":[{"content":"First","role":"system"},{"content":"Second","role":"user"}],"model":"gpt-4o","reasoning_effort":"none""#
            + streamFields + #","tools":["# + tool("zeta_tool") + "," + tool("alpha_tool") + "]}"
        #expect(baseline == Data(expected.utf8))

        let body = try #require(JSONSerialization.jsonObject(with: baseline) as? [String: Any])
        #expect(body["max_completion_tokens"] as? Int == 64)
        #expect(body["maxCompletionTokens"] == nil)
        #expect(body["reasoning_effort"] as? String == "none")
        for key in ["temperature", "user", "tool_choice", "prompt_cache_key", "prompt_cache_retention", "safety_identifier"] {
            #expect(body[key] == nil)
        }
        #expect(body["stream"] as? Bool == (streaming ? true : nil))
        #expect((body["stream_options"] as? [String: Bool]) == (streaming ? ["include_usage": true] : nil))
    }

    @Test(arguments: [false, true])
    func deterministicChatPreservesSignificantValues(streaming: Bool) async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let client = makeMockClient(json: deterministicChatFixture(streaming: streaming))
        let tools = deterministicTools()
        let baseline = try await sendDeterministicChat(client, tools: tools, streaming: streaming)
        let changedValue = try await sendDeterministicChat(client, tools: deterministicTools(schemaValue: "changed"), streaming: streaming)
        let reversedTools = try await sendDeterministicChat(client, tools: Array(tools.reversed()), streaming: streaming)
        let reversedMessages = try await sendDeterministicChat(client, tools: tools, streaming: streaming, reverseMessages: true)
        let reversedRequired = try await sendDeterministicChat(client, tools: deterministicTools(reverseRequired: true), streaming: streaming)
        let reversedEnum = try await sendDeterministicChat(client, tools: deterministicTools(reverseEnum: true), streaming: streaming)
        for changed in [changedValue, reversedTools, reversedMessages, reversedRequired, reversedEnum] {
            #expect(changed != baseline)
        }
    }

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

private func deterministicTools(
    reverseInsertion: Bool = false,
    schemaValue: String = "zulu",
    reverseRequired: Bool = false,
    reverseEnum: Bool = false
) -> [ChatCompletionTool] {
    func object(_ pairs: [(String, AnyCodable)]) -> [String: AnyCodable] {
        var result: [String: AnyCodable] = [:]
        for (key, value) in reverseInsertion ? Array(pairs.reversed()) : pairs {
            result[key] = value
        }
        return result
    }
    let required = reverseRequired ? ["alpha", "zeta"] : ["zeta", "alpha"]
    let values = reverseEnum ? ["alpha", schemaValue] : [schemaValue, "alpha"]
    let nested = object([
        ("type", AnyCodable("object")),
        ("required", AnyCodable(required)),
        ("properties", AnyCodable(object([
            ("zeta", AnyCodable(object([("type", AnyCodable("number"))]))),
            ("alpha", AnyCodable(object([("type", AnyCodable("boolean"))])))
        ])))
    ])
    let parameters = object([
        ("type", AnyCodable("object")),
        ("required", AnyCodable(required)),
        ("additionalProperties", AnyCodable(false)),
        ("properties", AnyCodable(object([
            ("zeta", AnyCodable(nested)),
            ("alpha", AnyCodable(object([("type", AnyCodable("string")), ("enum", AnyCodable(values))])))
        ])))
    ])
    return ["zeta_tool", "alpha_tool"].map {
        ChatCompletionTool(function: .init(name: $0, description: "Unchanged description", parameters: parameters, strict: true))
    }
}

private func deterministicChatFixture(streaming: Bool) -> String {
    if streaming {
        return """
        data: {"id":"offline","object":"chat.completion.chunk","created":1,"model":"gpt-4o","choices":[{"index":0,"delta":{"content":"OK"},"finish_reason":"stop"}]}

        data: {"id":"offline","object":"chat.completion.chunk","created":1,"model":"gpt-4o","choices":[],"usage":{"prompt_tokens":10,"completion_tokens":2,"total_tokens":12}}

        data: [DONE]

        """
    }
    return #"{"id":"offline","object":"chat.completion","created":1,"model":"gpt-4o","choices":[{"index":0,"message":{"role":"assistant","content":"OK"},"finish_reason":"stop"}],"usage":{"prompt_tokens":10,"completion_tokens":2,"total_tokens":12}}"#
}

private func sendDeterministicChat(
    _ client: OpenAI,
    tools: [ChatCompletionTool],
    streaming: Bool,
    reverseMessages: Bool = false
) async throws -> Data {
    let messages: [ChatCompletionMessage] = [.system("First"), .user("Second")]
    let ordered = reverseMessages ? Array(messages.reversed()) : messages
    if streaming {
        let stream = try await client.chat.completions.createStream(
            model: "gpt-4o", messages: ordered, maxCompletionTokens: 64, tools: tools,
            reasoningEffort: .disabled, streamOptions: .init(includeUsage: true)
        )
        var chunks: [ChatCompletionChunk] = []
        for try await chunk in stream { chunks.append(chunk) }
        #expect(chunks.count == 2)
        #expect(chunks.first?.choices.first?.delta?.content == "OK")
        #expect(chunks.last?.usage?.promptTokens == 10)
        #expect(chunks.last?.usage?.completionTokens == 2)
        #expect(chunks.last?.usage?.totalTokens == 12)
    } else {
        let response = try await client.chat.completions.create(
            model: "gpt-4o", messages: ordered, maxCompletionTokens: 64, tools: tools,
            reasoningEffort: .disabled
        )
        #expect(response.choices.first?.message.content == "OK")
        #expect(response.usage?.promptTokens == 10)
        #expect(response.usage?.completionTokens == 2)
        #expect(response.usage?.totalTokens == 12)
    }
    let request = try #require(MockURLProtocol.lastRequest)
    #expect(request.httpMethod == "POST")
    #expect(request.url?.absoluteString == "https://api.openai.com/v1/chat/completions")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    return try #require(MockURLProtocol.lastRequestBody)
}
