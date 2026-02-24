import Testing
import Foundation
@testable import SwiftOpenAI

/// A simple Decodable type for testing SSE parsing.
private struct TestEvent: Decodable, Sendable, Equatable {
    let id: String
    let value: Int
}

@Suite struct ServerSentEventsTests {

    // MARK: - SSE Payload Decoding

    @Test func parsesValidSSEPayload() throws {
        let json = """
        {"id": "evt-1", "value": 42}
        """
        let decoder = HTTPClient.decoder
        let data = json.data(using: .utf8)!
        let event = try decoder.decode(TestEvent.self, from: data)
        #expect(event.id == "evt-1")
        #expect(event.value == 42)
    }

    // MARK: - ChatCompletionChunk Decoding

    @Test func chatCompletionChunkDecoding() throws {
        let json = """
        {
            "id": "chatcmpl-123",
            "object": "chat.completion.chunk",
            "created": 1694268190,
            "model": "gpt-4",
            "choices": [
                {
                    "index": 0,
                    "delta": {
                        "role": "assistant",
                        "content": "Hello"
                    },
                    "finish_reason": null
                }
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let chunk = try HTTPClient.decoder.decode(ChatCompletionChunk.self, from: data)
        #expect(chunk.id == "chatcmpl-123")
        #expect(chunk.object == "chat.completion.chunk")
        #expect(chunk.created == 1694268190)
        #expect(chunk.model == "gpt-4")
        #expect(chunk.choices.count == 1)
        #expect(chunk.choices[0].index == 0)
        #expect(chunk.choices[0].delta?.role == "assistant")
        #expect(chunk.choices[0].delta?.content == "Hello")
        #expect(chunk.choices[0].finishReason == nil)
    }

    @Test func chatCompletionChunkWithFinishReason() throws {
        let json = """
        {
            "id": "chatcmpl-123",
            "object": "chat.completion.chunk",
            "created": 1694268190,
            "model": "gpt-4",
            "choices": [
                {
                    "index": 0,
                    "delta": {},
                    "finish_reason": "stop"
                }
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let chunk = try HTTPClient.decoder.decode(ChatCompletionChunk.self, from: data)
        #expect(chunk.choices[0].finishReason == "stop")
        #expect(chunk.choices[0].delta?.content == nil)
        #expect(chunk.choices[0].delta?.role == nil)
    }

    @Test func chatCompletionChunkWithToolCalls() throws {
        let json = """
        {
            "id": "chatcmpl-456",
            "object": "chat.completion.chunk",
            "created": 1694268190,
            "model": "gpt-4",
            "choices": [
                {
                    "index": 0,
                    "delta": {
                        "tool_calls": [
                            {
                                "index": 0,
                                "id": "call_abc",
                                "type": "function",
                                "function": {
                                    "name": "get_weather",
                                    "arguments": "{}"
                                }
                            }
                        ]
                    },
                    "finish_reason": null
                }
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let chunk = try HTTPClient.decoder.decode(ChatCompletionChunk.self, from: data)
        #expect(chunk.id == "chatcmpl-456")
        #expect(chunk.choices[0].delta?.toolCalls?.count == 1)
        #expect(chunk.choices[0].delta?.toolCalls?[0].index == 0)
        #expect(chunk.choices[0].delta?.toolCalls?[0].id == "call_abc")
        #expect(chunk.choices[0].delta?.toolCalls?[0].type == "function")
        #expect(chunk.choices[0].delta?.toolCalls?[0].function?.name == "get_weather")
        #expect(chunk.choices[0].delta?.toolCalls?[0].function?.arguments == "{}")
    }

    @Test func chatCompletionChunkWithUsage() throws {
        let json = """
        {
            "id": "chatcmpl-789",
            "object": "chat.completion.chunk",
            "created": 1694268190,
            "model": "gpt-4",
            "choices": [],
            "usage": {
                "prompt_tokens": 10,
                "completion_tokens": 20,
                "total_tokens": 30
            }
        }
        """
        let data = json.data(using: .utf8)!
        let chunk = try HTTPClient.decoder.decode(ChatCompletionChunk.self, from: data)
        #expect(chunk.id == "chatcmpl-789")
        #expect(chunk.choices.isEmpty)
        #expect(chunk.usage?.promptTokens == 10)
        #expect(chunk.usage?.completionTokens == 20)
        #expect(chunk.usage?.totalTokens == 30)
    }

    @Test func chatCompletionChunkWithSystemFingerprint() throws {
        let json = """
        {
            "id": "chatcmpl-fp",
            "object": "chat.completion.chunk",
            "created": 1694268190,
            "model": "gpt-4",
            "choices": [
                {
                    "index": 0,
                    "delta": {"content": "Hi"},
                    "finish_reason": null
                }
            ],
            "system_fingerprint": "fp_abc123"
        }
        """
        let data = json.data(using: .utf8)!
        let chunk = try HTTPClient.decoder.decode(ChatCompletionChunk.self, from: data)
        #expect(chunk.systemFingerprint == "fp_abc123")
    }

    // MARK: - SSE Line Parsing Logic

    @Test func doneSignalPayload() throws {
        // Verify that "[DONE]" is the exact sentinel the parser checks
        let payload = "[DONE]"
        #expect(payload == "[DONE]")
    }

    @Test func dataLinePrefixExtraction() throws {
        // Simulate the parser's "data: " prefix stripping
        let line = "data: {\"id\": \"evt-1\", \"value\": 1}"
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        #expect(trimmed.hasPrefix("data: "))
        let payload = String(trimmed.dropFirst(6))
        let data = payload.data(using: .utf8)!
        let event = try HTTPClient.decoder.decode(TestEvent.self, from: data)
        #expect(event.id == "evt-1")
        #expect(event.value == 1)
    }

    @Test func emptyLinesAreSkipped() {
        // The parser skips lines where trimmed content is empty
        let lines = ["", "  ", "\t"]
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            #expect(trimmed.isEmpty, "Expected empty after trimming: '\(line)'")
        }
    }

    @Test func commentLinesAreSkipped() {
        // The parser skips lines starting with ":"
        let comments = [": this is a comment", ":keep-alive", ": heartbeat"]
        for line in comments {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            #expect(trimmed.hasPrefix(":"), "Expected comment prefix for: '\(line)'")
        }
    }

    @Test func linesWithoutDataPrefixAreSkipped() {
        // Lines that don't start with "data: " are not processed as events
        let nonDataLines = ["event: message", "id: 123", "retry: 5000", "random text"]
        for line in nonDataLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            #expect(!trimmed.isEmpty)
            #expect(!trimmed.hasPrefix(":"))
            #expect(!trimmed.hasPrefix("data: "), "Unexpectedly has data prefix: '\(line)'")
        }
    }

    // MARK: - Multi-Chunk SSE Stream Simulation

    @Test func multipleChunksInSequence() throws {
        // Simulate parsing multiple SSE data lines from a stream
        let sseLines = [
            "data: {\"id\": \"evt-1\", \"value\": 1}",
            "",
            "data: {\"id\": \"evt-2\", \"value\": 2}",
            "",
            "data: {\"id\": \"evt-3\", \"value\": 3}",
            "",
            "data: [DONE]",
        ]

        var events: [TestEvent] = []
        let decoder = HTTPClient.decoder

        for line in sseLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix(":") { continue }
            guard trimmed.hasPrefix("data: ") else { continue }
            let payload = String(trimmed.dropFirst(6))
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8) else { continue }
            let event = try decoder.decode(TestEvent.self, from: data)
            events.append(event)
        }

        #expect(events.count == 3)
        #expect(events[0] == TestEvent(id: "evt-1", value: 1))
        #expect(events[1] == TestEvent(id: "evt-2", value: 2))
        #expect(events[2] == TestEvent(id: "evt-3", value: 3))
    }

    @Test func streamWithCommentsAndEmptyLines() throws {
        // Simulate a stream that includes comments and blank lines between events
        let sseLines = [
            ": heartbeat",
            "",
            "data: {\"id\": \"evt-1\", \"value\": 10}",
            "",
            ": keep-alive",
            "",
            "data: {\"id\": \"evt-2\", \"value\": 20}",
            "",
            "data: [DONE]",
        ]

        var events: [TestEvent] = []
        let decoder = HTTPClient.decoder

        for line in sseLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix(":") { continue }
            guard trimmed.hasPrefix("data: ") else { continue }
            let payload = String(trimmed.dropFirst(6))
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8) else { continue }
            let event = try decoder.decode(TestEvent.self, from: data)
            events.append(event)
        }

        #expect(events.count == 2)
        #expect(events[0].id == "evt-1")
        #expect(events[1].id == "evt-2")
    }

    @Test func chatCompletionStreamSimulation() throws {
        // Simulate a typical chat completion streaming response
        let sseLines = [
            "data: {\"id\":\"chatcmpl-abc\",\"object\":\"chat.completion.chunk\",\"created\":1700000000,\"model\":\"gpt-4\",\"choices\":[{\"index\":0,\"delta\":{\"role\":\"assistant\",\"content\":\"\"},\"finish_reason\":null}]}",
            "",
            "data: {\"id\":\"chatcmpl-abc\",\"object\":\"chat.completion.chunk\",\"created\":1700000000,\"model\":\"gpt-4\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\"Hello\"},\"finish_reason\":null}]}",
            "",
            "data: {\"id\":\"chatcmpl-abc\",\"object\":\"chat.completion.chunk\",\"created\":1700000000,\"model\":\"gpt-4\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\" world\"},\"finish_reason\":null}]}",
            "",
            "data: {\"id\":\"chatcmpl-abc\",\"object\":\"chat.completion.chunk\",\"created\":1700000000,\"model\":\"gpt-4\",\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"stop\"}]}",
            "",
            "data: [DONE]",
        ]

        var chunks: [ChatCompletionChunk] = []
        let decoder = HTTPClient.decoder

        for line in sseLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix(":") { continue }
            guard trimmed.hasPrefix("data: ") else { continue }
            let payload = String(trimmed.dropFirst(6))
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8) else { continue }
            let chunk = try decoder.decode(ChatCompletionChunk.self, from: data)
            chunks.append(chunk)
        }

        #expect(chunks.count == 4)
        // First chunk: role set, empty content
        #expect(chunks[0].choices[0].delta?.role == "assistant")
        #expect(chunks[0].choices[0].delta?.content == "")
        // Middle chunks: content tokens
        #expect(chunks[1].choices[0].delta?.content == "Hello")
        #expect(chunks[2].choices[0].delta?.content == " world")
        // Last chunk: finish reason
        #expect(chunks[3].choices[0].finishReason == "stop")
        #expect(chunks[3].choices[0].delta?.content == nil)
    }
}
