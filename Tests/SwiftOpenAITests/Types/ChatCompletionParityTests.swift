import Foundation
import Testing
@testable import SwiftOpenAI

@Suite struct ChatCompletionParityTests {

    // MARK: - Test helpers

    private func encode<T: Encodable>(_ value: T) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(value)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        return json
    }

    private func encodeRaw<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return try encoder.encode(value)
    }

    private func minimalParams(
        reasoningEffort: ReasoningEffort? = nil,
        streamOptions: ChatCompletionStreamOptions? = nil,
        verbosity: Verbosity? = nil,
        promptCacheKey: String? = nil,
        promptCacheRetention: PromptCacheRetention? = nil,
        safetyIdentifier: String? = nil,
        webSearchOptions: WebSearchOptions? = nil,
        prediction: ChatCompletionPredictionContent? = nil,
        serviceTier: ServiceTier? = nil,
        tools: [ChatCompletionTool]? = nil,
        toolChoice: ChatCompletionToolChoice? = nil
    ) -> ChatCompletionCreateParams {
        ChatCompletionCreateParams(
            model: "gpt-4o",
            messages: [.user("hi")],
            tools: tools,
            toolChoice: toolChoice,
            serviceTier: serviceTier,
            reasoningEffort: reasoningEffort,
            streamOptions: streamOptions,
            verbosity: verbosity,
            promptCacheKey: promptCacheKey,
            promptCacheRetention: promptCacheRetention,
            safetyIdentifier: safetyIdentifier,
            webSearchOptions: webSearchOptions,
            prediction: prediction
        )
    }

    // MARK: - Tier A: ReasoningEffort

    @Test func reasoningEffortEncodesLow() throws {
        let json = try encode(minimalParams(reasoningEffort: .low))
        #expect(json["reasoning_effort"] as? String == "low")
    }

    @Test func reasoningEffortEncodesMinimal() throws {
        let json = try encode(minimalParams(reasoningEffort: .minimal))
        #expect(json["reasoning_effort"] as? String == "minimal")
    }

    @Test func reasoningEffortEncodesHigh() throws {
        let json = try encode(minimalParams(reasoningEffort: .high))
        #expect(json["reasoning_effort"] as? String == "high")
    }

    @Test func reasoningEffortEncodesXhigh() throws {
        let json = try encode(minimalParams(reasoningEffort: .xhigh))
        #expect(json["reasoning_effort"] as? String == "xhigh")
    }

    @Test func reasoningEffortEncodesOther() throws {
        let json = try encode(minimalParams(reasoningEffort: .other("custom-level")))
        #expect(json["reasoning_effort"] as? String == "custom-level")
    }

    @Test func reasoningEffortEncodesNone() throws {
        let json = try encode(minimalParams(reasoningEffort: .disabled))
        #expect(json["reasoning_effort"] as? String == "none")
    }

    @Test func reasoningEffortOmittedWhenNil() throws {
        let json = try encode(minimalParams())
        #expect(json["reasoning_effort"] == nil)
    }

    // MARK: - Tier A: StreamOptions

    @Test func streamOptionsIncludeUsage() throws {
        let opts = ChatCompletionStreamOptions(includeUsage: true)
        let json = try encode(opts)
        #expect(json["include_usage"] as? Bool == true)
        #expect(json["include_obfuscation"] == nil)
    }

    @Test func streamOptionsBothFlags() throws {
        let opts = ChatCompletionStreamOptions(includeUsage: true, includeObfuscation: false)
        let json = try encode(opts)
        #expect(json["include_usage"] as? Bool == true)
        #expect(json["include_obfuscation"] as? Bool == false)
    }

    @Test func streamOptionsOnRequest() throws {
        let json = try encode(minimalParams(
            streamOptions: ChatCompletionStreamOptions(includeUsage: true)
        ))
        let streamOpts = json["stream_options"] as? [String: Any]
        #expect(streamOpts != nil)
        #expect(streamOpts?["include_usage"] as? Bool == true)
    }

    // MARK: - Tier A: Function Tool strict

    @Test func functionToolStrict() throws {
        let tool = ChatCompletionTool.function(
            ChatCompletionToolFunction(name: "f", strict: true)
        )
        let json = try encode(tool)
        #expect(json["type"] as? String == "function")
        let fn = json["function"] as? [String: Any]
        #expect(fn?["name"] as? String == "f")
        #expect(fn?["strict"] as? Bool == true)
    }

    @Test func functionToolStrictOmittedWhenNil() throws {
        let tool = ChatCompletionTool.function(
            ChatCompletionToolFunction(name: "f")
        )
        let json = try encode(tool)
        let fn = json["function"] as? [String: Any]
        #expect(fn?["strict"] == nil)
    }

    // MARK: - Tier B: Verbosity

    @Test func verbosityEncodesLow() throws {
        let json = try encode(minimalParams(verbosity: .low))
        #expect(json["verbosity"] as? String == "low")
    }

    @Test func verbosityEncodesMedium() throws {
        let json = try encode(minimalParams(verbosity: .medium))
        #expect(json["verbosity"] as? String == "medium")
    }

    @Test func verbosityEncodesHigh() throws {
        let json = try encode(minimalParams(verbosity: .high))
        #expect(json["verbosity"] as? String == "high")
    }

    @Test func verbosityEncodesOther() throws {
        let json = try encode(minimalParams(verbosity: .other("X")))
        #expect(json["verbosity"] as? String == "X")
    }

    // MARK: - Tier B: Name on messages

    @Test func nameOnSystemMessage() throws {
        let msg = ChatCompletionMessage.system("hi", name: "alice")
        let json = try encode(msg)
        #expect(json["role"] as? String == "system")
        #expect(json["content"] as? String == "hi")
        #expect(json["name"] as? String == "alice")
    }

    @Test func nameOnUserMessage() throws {
        let msg = ChatCompletionMessage.user("hello", name: "bob")
        let json = try encode(msg)
        #expect(json["role"] as? String == "user")
        #expect(json["content"] as? String == "hello")
        #expect(json["name"] as? String == "bob")
    }

    @Test func nameOnAssistantMessage() throws {
        let msg = ChatCompletionMessage.assistant("response", name: "assistant1")
        let json = try encode(msg)
        #expect(json["role"] as? String == "assistant")
        #expect(json["content"] as? String == "response")
        #expect(json["name"] as? String == "assistant1")
    }

    @Test func nameOnToolMessage() throws {
        let msg = ChatCompletionMessage.tool("ok", toolCallId: "tc1", name: "toolname")
        let json = try encode(msg)
        #expect(json["role"] as? String == "tool")
        #expect(json["content"] as? String == "ok")
        #expect(json["name"] as? String == "toolname")
    }

    @Test func nameOmittedWhenNilSystem() throws {
        let json = try encode(ChatCompletionMessage.system("hi"))
        #expect(json["name"] == nil)
    }

    @Test func nameOmittedWhenNilUser() throws {
        let json = try encode(ChatCompletionMessage.user("hi"))
        #expect(json["name"] == nil)
    }

    @Test func nameOmittedWhenNilAssistant() throws {
        let json = try encode(ChatCompletionMessage.assistant("hi"))
        #expect(json["name"] == nil)
    }

    @Test func nameOmittedWhenNilTool() throws {
        let json = try encode(ChatCompletionMessage.tool("ok", toolCallId: "tc1"))
        #expect(json["name"] == nil)
    }

    // MARK: - Tier B: Refusal on assistant

    @Test func refusalOnAssistantInput() throws {
        let msg = ChatCompletionMessage.assistant("Cannot help", refusal: "violates policy")
        let json = try encode(msg)
        #expect(json["role"] as? String == "assistant")
        #expect(json["content"] as? String == "Cannot help")
        #expect(json["refusal"] as? String == "violates policy")
    }

    // MARK: - Tier B: ServiceTier

    @Test func serviceTierPriority() throws {
        let json = try encode(minimalParams(serviceTier: .priority))
        #expect(json["service_tier"] as? String == "priority")
    }

    @Test func serviceTierAuto() throws {
        let json = try encode(minimalParams(serviceTier: .auto))
        #expect(json["service_tier"] as? String == "auto")
    }

    @Test func serviceTierDefault() throws {
        let json = try encode(minimalParams(serviceTier: .default))
        #expect(json["service_tier"] as? String == "default")
    }

    @Test func serviceTierFlex() throws {
        let json = try encode(minimalParams(serviceTier: .flex))
        #expect(json["service_tier"] as? String == "flex")
    }

    @Test func serviceTierScale() throws {
        let json = try encode(minimalParams(serviceTier: .scale))
        #expect(json["service_tier"] as? String == "scale")
    }

    @Test func serviceTierOther() throws {
        let json = try encode(minimalParams(serviceTier: .other("custom")))
        #expect(json["service_tier"] as? String == "custom")
    }

    @Test func serviceTierStringLiteral() throws {
        let tier: ServiceTier = "auto"
        let json = try encode(minimalParams(serviceTier: tier))
        #expect(json["service_tier"] as? String == "auto")
    }

    // MARK: - Tier B: Tool calls snake_case

    @Test func toolCallsSnakeCase() throws {
        let msg = ChatCompletionMessage.assistant(
            "x",
            toolCalls: [
                ChatCompletionToolCall(
                    id: "t",
                    type: "function",
                    function: FunctionCall(name: "n", arguments: "{}")
                )
            ]
        )
        let json = try encode(msg)
        // The CodingKeys in ChatCompletionMessage use "toolCalls" which becomes "tool_calls" via convertToSnakeCase
        #expect(json["tool_calls"] != nil)
        let calls = json["tool_calls"] as? [[String: Any]]
        #expect(calls?.count == 1)
        let call = calls?.first
        #expect(call?["function"] as? [String: Any] != nil)
    }

    @Test func toolMessageToolCallIdSnakeCase() throws {
        let msg = ChatCompletionMessage.tool("ok", toolCallId: "t")
        let json = try encode(msg)
        #expect(json["tool_call_id"] as? String == "t")
    }

    // MARK: - Tier C: Prompt cache

    @Test func promptCacheKey() throws {
        let json = try encode(minimalParams(promptCacheKey: "my-cache-key"))
        #expect(json["prompt_cache_key"] as? String == "my-cache-key")
    }

    @Test func promptCacheRetentionInMemory() throws {
        let json = try encode(minimalParams(promptCacheRetention: .inMemory))
        #expect(json["prompt_cache_retention"] as? String == "in_memory")
    }

    @Test func promptCacheRetention24h() throws {
        let json = try encode(minimalParams(promptCacheRetention: .h24))
        #expect(json["prompt_cache_retention"] as? String == "24h")
    }

    // MARK: - Tier C: Safety identifier

    @Test func safetyIdentifier() throws {
        let json = try encode(minimalParams(safetyIdentifier: "safety-123"))
        #expect(json["safety_identifier"] as? String == "safety-123")
    }

    // MARK: - Tier C: Web search options

    @Test func webSearchOptionsBasic() throws {
        let opts = WebSearchOptions(searchContextSize: .high)
        let json = try encode(opts)
        #expect(json["search_context_size"] as? String == "high")
    }

    @Test func webSearchOptionsWithLocation() throws {
        let opts = WebSearchOptions(
            searchContextSize: .medium,
            userLocation: WebSearchOptions.UserLocation(
                approximate: WebSearchOptions.UserLocation.Approximate(
                    city: "Seattle",
                    country: "US",
                    region: "WA",
                    timezone: "America/Los_Angeles"
                )
            )
        )
        let json = try encode(opts)
        let userLoc = json["user_location"] as? [String: Any]
        #expect(userLoc?["type"] as? String == "approximate")
        let approx = userLoc?["approximate"] as? [String: Any]
        #expect(approx?["city"] as? String == "Seattle")
        #expect(approx?["country"] as? String == "US")
        #expect(approx?["region"] as? String == "WA")
        #expect(approx?["timezone"] as? String == "America/Los_Angeles")
    }

    @Test func webSearchOptionsOnRequest() throws {
        let json = try encode(minimalParams(
            webSearchOptions: WebSearchOptions(searchContextSize: .low)
        ))
        let wsOpts = json["web_search_options"] as? [String: Any]
        #expect(wsOpts != nil)
        #expect(wsOpts?["search_context_size"] as? String == "low")
    }

    // MARK: - Tier C: Prediction content

    @Test func predictionTextContent() throws {
        let pred = ChatCompletionPredictionContent(content: .text("expected"))
        let json = try encode(pred)
        #expect(json["type"] as? String == "content")
        #expect(json["content"] as? String == "expected")
    }

    @Test func predictionParts() throws {
        let pred = ChatCompletionPredictionContent(
            content: .parts([
                ChatCompletionPredictionContent.Content.TextPart(text: "part1"),
                ChatCompletionPredictionContent.Content.TextPart(text: "part2"),
            ])
        )
        let json = try encode(pred)
        #expect(json["type"] as? String == "content")
        let parts = json["content"] as? [[String: Any]]
        #expect(parts?.count == 2)
        #expect(parts?[0]["type"] as? String == "text")
        #expect(parts?[0]["text"] as? String == "part1")
        #expect(parts?[1]["text"] as? String == "part2")
    }

    // MARK: - Tier C: Custom tools

    @Test func customToolText() throws {
        let tool = ChatCompletionTool.custom(
            ChatCompletionCustomTool(name: "t", format: .text)
        )
        let json = try encode(tool)
        #expect(json["type"] as? String == "custom")
        let custom = json["custom"] as? [String: Any]
        #expect(custom?["name"] as? String == "t")
        let format = custom?["format"] as? [String: Any]
        #expect(format?["type"] as? String == "text")
    }

    @Test func customToolGrammarLark() throws {
        let tool = ChatCompletionTool.custom(
            ChatCompletionCustomTool(
                name: "t",
                format: .grammar(definition: "rule: 'a'", syntax: .lark)
            )
        )
        let json = try encode(tool)
        #expect(json["type"] as? String == "custom")
        let custom = json["custom"] as? [String: Any]
        #expect(custom?["name"] as? String == "t")
        let format = custom?["format"] as? [String: Any]
        #expect(format?["type"] as? String == "grammar")
        let grammar = format?["grammar"] as? [String: Any]
        #expect(grammar?["definition"] as? String == "rule: 'a'")
        #expect(grammar?["syntax"] as? String == "lark")
    }

    @Test func customToolGrammarRegex() throws {
        let tool = ChatCompletionTool.custom(
            ChatCompletionCustomTool(
                name: "t",
                format: .grammar(definition: "[0-9]+", syntax: .regex)
            )
        )
        let json = try encode(tool)
        let custom = json["custom"] as? [String: Any]
        let format = custom?["format"] as? [String: Any]
        #expect(format?["type"] as? String == "grammar")
        let grammar = format?["grammar"] as? [String: Any]
        #expect(grammar?["syntax"] as? String == "regex")
    }

    // MARK: - Tier C: Tool choice

    @Test func toolChoiceCustomNamed() throws {
        let choice = ChatCompletionToolChoice.custom("toolname")
        let json = try encode(choice)
        #expect(json["type"] as? String == "custom")
        let custom = json["custom"] as? [String: String]
        #expect(custom?["name"] == "toolname")
    }

    @Test func toolChoiceAllowedToolsAuto() throws {
        let choice = ChatCompletionToolChoice.allowedTools(
            mode: .auto,
            tools: [.function(ChatCompletionToolFunction(name: "f1"))]
        )
        let json = try encode(choice)
        #expect(json["type"] as? String == "allowed_tools")
        let allowed = json["allowed_tools"] as? [String: Any]
        #expect(allowed?["mode"] as? String == "auto")
        let tools = allowed?["tools"] as? [[String: Any]]
        #expect(tools?.count == 1)
        #expect(tools?[0]["type"] as? String == "function")
    }

    @Test func toolChoiceAllowedToolsRequired() throws {
        let choice = ChatCompletionToolChoice.allowedTools(
            mode: .required,
            tools: [.function(ChatCompletionToolFunction(name: "f2"))]
        )
        let json = try encode(choice)
        let allowed = json["allowed_tools"] as? [String: Any]
        #expect(allowed?["mode"] as? String == "required")
    }

    // MARK: - Round-trip tests

    @Test func chatCompletionMessageRoundTripWithName() throws {
        let original = ChatCompletionMessage.user("hi", name: "alice")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(ChatCompletionMessage.self, from: data)
        if case .user(let content, let name) = decoded {
            #expect(content == "hi")
            #expect(name == "alice")
        } else {
            Issue.record("Expected .user case, got \(decoded)")
        }
    }

    @Test func chatCompletionMessageRoundTripAssistantRefusal() throws {
        let original = ChatCompletionMessage.assistant("content", refusal: "policy")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(ChatCompletionMessage.self, from: data)
        if case .assistant(let content, let name, let refusal, _) = decoded {
            #expect(content == "content")
            #expect(refusal == "policy")
            #expect(name == nil)
        } else {
            Issue.record("Expected .assistant case, got \(decoded)")
        }
    }

    @Test func chatCompletionToolDecodesFunctionAndCustom() throws {
        // ChatCompletionTool is Encodable only (not Codable), so we test encoding only
        // Verify function tool encoding round-trips to expected JSON shape
        let fnTool = ChatCompletionTool.function(ChatCompletionToolFunction(name: "f"))
        let fnJson = try encode(fnTool)
        #expect(fnJson["type"] as? String == "function")
        let fnBody = fnJson["function"] as? [String: Any]
        #expect(fnBody?["name"] as? String == "f")

        let customTool = ChatCompletionTool.custom(ChatCompletionCustomTool(name: "c"))
        let customJson = try encode(customTool)
        #expect(customJson["type"] as? String == "custom")
        let customBody = customJson["custom"] as? [String: Any]
        #expect(customBody?["name"] as? String == "c")
    }
}
