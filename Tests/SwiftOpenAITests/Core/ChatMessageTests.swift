import Testing
import Foundation
@testable import SwiftOpenAI

// MARK: - ChatMessage Decoding Tests

extension MockAPITests {

    @Test func chatMessageAssistantDecodesNilContent() throws {
        let json = """
        {"role": "assistant", "content": null, "tool_calls": [{"id": "c1", "type": "function", "function": {"name": "f", "arguments": "{}"}}]}
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let msg = try decoder.decode(ChatCompletionMessage.self, from: json.data(using: .utf8)!)
        if case .assistant(let content, let toolCalls) = msg {
            #expect(content == nil)
            #expect(toolCalls?.count == 1)
        } else {
            #expect(Bool(false), "Expected .assistant case")
        }
    }

    @Test func chatMessageAssistantDecodesStringContent() throws {
        let json = """
        {"role": "assistant", "content": "Hello"}
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let msg = try decoder.decode(ChatCompletionMessage.self, from: json.data(using: .utf8)!)
        if case .assistant(let content, let toolCalls) = msg {
            #expect(content == "Hello")
            #expect(toolCalls == nil)
        } else {
            #expect(Bool(false), "Expected .assistant case")
        }
    }

    @Test func chatMessageOtherRoleDecodes() throws {
        let json = """
        {"role": "developer", "content": "system instructions"}
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let msg = try decoder.decode(ChatCompletionMessage.self, from: json.data(using: .utf8)!)
        if case .other(let role, let content) = msg {
            #expect(role == "developer")
            #expect(content == "system instructions")
        } else {
            #expect(Bool(false), "Expected .other case, got \(msg)")
        }
    }

    @Test func chatMessageOtherRoleDecodesNilContent() throws {
        let json = """
        {"role": "custom_role"}
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let msg = try decoder.decode(ChatCompletionMessage.self, from: json.data(using: .utf8)!)
        if case .other(let role, let content) = msg {
            #expect(role == "custom_role")
            #expect(content == nil)
        } else {
            #expect(Bool(false), "Expected .other case")
        }
    }

    @Test func chatMessageOtherRoleRoundtrips() throws {
        let original = ChatCompletionMessage.other(role: "developer", content: "instructions")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(ChatCompletionMessage.self, from: data)
        if case .other(let role, let content) = decoded {
            #expect(role == "developer")
            #expect(content == "instructions")
        } else {
            #expect(Bool(false), "Expected .other case after roundtrip")
        }
    }

    @Test func chatMessageAssistantNilContentRoundtrips() throws {
        let original = ChatCompletionMessage.assistant(nil, toolCalls: nil)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(ChatCompletionMessage.self, from: data)
        if case .assistant(let content, let toolCalls) = decoded {
            #expect(content == nil)
            #expect(toolCalls == nil)
        } else {
            #expect(Bool(false), "Expected .assistant case after roundtrip")
        }
    }
}
