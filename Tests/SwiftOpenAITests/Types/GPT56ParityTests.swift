import Foundation
import Testing
@testable import SwiftOpenAI

@Suite struct GPT56ParityTypeTests {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private func object<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try encoder.encode(value)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func value<T: Encodable>(_ value: T) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: encoder.encode(value))
    }

    @Test func promptCacheOptionsUseExactKeysAndRoundTripUnknownValues() async throws {
        let modes: [(PromptCacheMode, String)] = [
            (.implicit, "implicit"),
            (.explicit, "explicit"),
            (.other("future_mode"), "future_mode"),
        ]

        for (mode, literal) in modes {
            let options = PromptCacheOptions(mode: mode, ttl: .m30)
            let json = try object(options)
            #expect(Set(json.keys) == ["mode", "ttl"])
            #expect(json["mode"] as? String == literal)
            #expect(json["ttl"] as? String == "30m")
            #expect(json["cache_control"] == nil)

            let decoded = try decoder.decode(
                PromptCacheOptions.self,
                from: encoder.encode(options)
            )
            #expect(decoded == options)
        }

        let unknownTTL = PromptCacheOptions(ttl: .other("2h"))
        let unknownJSON = try object(unknownTTL)
        #expect(unknownJSON["ttl"] as? String == "2h")
        let decodedUnknownTTL = try decoder.decode(
            PromptCacheOptions.self,
            from: encoder.encode(unknownTTL)
        )
        #expect(decodedUnknownTTL == unknownTTL)
    }

    @Test func promptCacheBreakpointUsesExplicitModeAndNeverCacheControl() async throws {
        let breakpoint = PromptCacheBreakpoint()
        let json = try object(breakpoint)
        #expect(Set(json.keys) == ["mode"])
        #expect(json["mode"] as? String == "explicit")
        #expect(json["cache_control"] == nil)

        let decoded = try decoder.decode(
            PromptCacheBreakpoint.self,
            from: Data(#"{"mode":"explicit"}"#.utf8)
        )
        #expect(decoded == breakpoint)

        for invalidMode in ["implicit", "future", ""] {
            let data = try encoder.encode(["mode": invalidMode])
            #expect(throws: DecodingError.self) {
                _ = try decoder.decode(PromptCacheBreakpoint.self, from: data)
            }
        }
    }

    @Test func jsonValueDictionaryLiteralUsesLastDuplicateValue() async throws {
        let value: JSONValue = [
            "duplicate": "first",
            "stable": true,
            "duplicate": "last",
        ]

        guard case .object(let object) = value else {
            Issue.record("Expected a JSON object")
            return
        }
        #expect(object.count == 2)
        #expect(object["duplicate"] == .string("last"))
        #expect(object["stable"] == .bool(true))
    }

    @Test func jsonNumberPreservesDecimalPrecisionAndIntegerRanges() async throws {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        let preciseLiteral = "0.12345678901234567890123456789012345678"
        let expectedDecimal = try #require(
            Decimal(
                string: preciseLiteral,
                locale: Locale(identifier: "en_US_POSIX")
            )
        )

        let preciseValue = try decoder.decode(
            JSONValue.self,
            from: Data(preciseLiteral.utf8)
        )
        guard case .number(let preciseNumber) = preciseValue else {
            Issue.record("Expected a Decimal-backed JSON number")
            return
        }
        #expect(preciseNumber.decimalValue == expectedDecimal)

        let reencodedData = try encoder.encode(preciseValue)
        let roundTrippedValue = try decoder.decode(JSONValue.self, from: reencodedData)
        #expect(roundTrippedValue == preciseValue)

        let signedValue = try decoder.decode(
            JSONValue.self,
            from: Data("-9223372036854775808".utf8)
        )
        #expect(signedValue == .integer(Int64.min))

        let unsignedValue = try decoder.decode(
            JSONValue.self,
            from: Data("18446744073709551615".utf8)
        )
        #expect(unsignedValue == .unsignedInteger(UInt64.max))

        for invalidLiteral in ["1e128", "1.2.3"] {
            do {
                _ = try decoder.decode(
                    JSONValue.self,
                    from: Data(invalidLiteral.utf8)
                )
                Issue.record("Expected \(invalidLiteral) to fail JSONValue decoding")
            } catch {
                // Expected: out-of-range and malformed public JSON inputs must throw.
            }
        }
    }

    @Test func jsonNumberRejectsDecimalNaNConstruction() async throws {
        let number = JSONNumber(Decimal.nan)

        #expect(number == nil)
    }

    @Test func jsonNumberRejectsNonFiniteDoubleConstruction() async throws {
        let nan = JSONNumber(Double.nan)
        let positiveInfinity = JSONNumber(Double.infinity)
        let negativeInfinity = JSONNumber(-Double.infinity)

        #expect(nan == nil)
        #expect(positiveInfinity == nil)
        #expect(negativeInfinity == nil)
    }

    @Test func jsonNumberFiniteDecimalsRoundTripWithDecimalSemantics() async throws {
        let literals = [
            "0",
            "-42.125",
            "1234567890.0001",
            "0.00000000000000000001",
        ]
        let decimals = try literals.map {
            try #require(
                Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX"))
            )
        }

        for decimal in decimals {
            let number = try #require(JSONNumber(decimal))
            let encoded = try JSONEncoder().encode(number)
            let decoded = try JSONDecoder().decode(JSONNumber.self, from: encoded)

            #expect(decoded.decimalValue == decimal)
            #expect(decoded == number)
        }
    }

    @Test func jsonNumberRoundTripDoesNotRequireRawLexicalPreservation() async throws {
        let lexicalForm = Data("1.2300e2".utf8)
        let expectedDecimal = try #require(
            Decimal(string: "123", locale: Locale(identifier: "en_US_POSIX"))
        )
        let decoded = try JSONDecoder().decode(JSONNumber.self, from: lexicalForm)
        let reencoded = try JSONEncoder().encode(decoded)
        let roundTripped = try JSONDecoder().decode(JSONNumber.self, from: reencoded)

        #expect(decoded.decimalValue == expectedDecimal)
        #expect(roundTripped.decimalValue == expectedDecimal)
        #expect(roundTripped == decoded)
    }

    @Test func chatRequestContentFactoriesEncodeExactShapes() async throws {
        let breakpoint = PromptCacheBreakpoint()
        let cases: [(ChatCompletionRequestContentPart, JSONValue)] = [
            (
                .text("hello", promptCacheBreakpoint: breakpoint),
                [
                    "type": "text",
                    "text": "hello",
                    "prompt_cache_breakpoint": ["mode": "explicit"],
                ]
            ),
            (
                .imageURL(
                    ChatCompletionImageURL(
                        url: "https://example.com/image.png",
                        detail: .high
                    ),
                    promptCacheBreakpoint: breakpoint
                ),
                [
                    "type": "image_url",
                    "image_url": [
                        "url": "https://example.com/image.png",
                        "detail": "high",
                    ],
                    "prompt_cache_breakpoint": ["mode": "explicit"],
                ]
            ),
            (
                .inputAudio(
                    data: "YXVkaW8=",
                    format: "wav",
                    promptCacheBreakpoint: breakpoint
                ),
                [
                    "type": "input_audio",
                    "input_audio": ["data": "YXVkaW8=", "format": "wav"],
                    "prompt_cache_breakpoint": ["mode": "explicit"],
                ]
            ),
            (
                .file(
                    data: "ZmlsZQ==",
                    filename: "notes.txt",
                    promptCacheBreakpoint: breakpoint
                ),
                [
                    "type": "file",
                    "file": ["file_data": "ZmlsZQ==", "filename": "notes.txt"],
                    "prompt_cache_breakpoint": ["mode": "explicit"],
                ]
            ),
            (
                .file(id: "file_123", promptCacheBreakpoint: breakpoint),
                [
                    "type": "file",
                    "file": ["file_id": "file_123"],
                    "prompt_cache_breakpoint": ["mode": "explicit"],
                ]
            ),
        ]

        for (part, expected) in cases {
            #expect(part.jsonValue == expected)
            let json = try object(part)
            #expect(json["cache_control"] == nil)
        }
    }

    @Test func chatRequestContentPreservesNestedUnknownJSONWhileLegacyRemainsLimited() async throws {
        let source = """
        {
          "type": "vendor_part",
          "nested": {"array": [1, true, null, {"deep": "value"}]},
          "vendor_flag": 2.5
        }
        """
        let data = Data(source.utf8)
        let expected = try JSONDecoder().decode(JSONValue.self, from: data)
        let requestPart = try decoder.decode(ChatCompletionRequestContentPart.self, from: data)
        #expect(requestPart.jsonValue == expected)
        let encodedRequestPart = try encoder.encode(requestPart)
        let decodedRequestPart = try JSONDecoder().decode(
            JSONValue.self,
            from: encodedRequestPart
        )
        #expect(decodedRequestPart == expected)

        let legacy = try decoder.decode(ChatCompletionContentPart.self, from: data)
        guard case .other(let type) = legacy else {
            Issue.record("Expected the documented legacy-limited .other case")
            return
        }
        #expect(type == "vendor_part")
        let legacyValue = try value(legacy)
        #expect(legacyValue == ["type": "vendor_part"])
    }

    @Test func chatRequestContentAndMessagesBridgeEveryLegacyCaseWithoutWireChanges() async throws {
        let legacyParts: [ChatCompletionContentPart] = [
            .text("hello"),
            .imageURL(ChatCompletionImageURL(
                url: "https://example.com/image.png",
                detail: .other("future_detail")
            )),
            .other(type: "future_part"),
        ]
        for part in legacyParts {
            let legacyValue = try value(part)
            #expect(ChatCompletionRequestContentPart(part).jsonValue == legacyValue)
        }

        let toolCall = ChatCompletionToolCall(
            id: "call_1",
            function: FunctionCall(name: "lookup", arguments: #"{"id":1}"#)
        )
        let legacyMessages: [ChatCompletionMessage] = [
            .system("system", name: "s"),
            .user("user", name: "u"),
            .userParts(legacyParts, name: "parts"),
            .assistant(
                nil,
                name: "assistant",
                refusal: "refusal",
                toolCalls: [toolCall]
            ),
            .tool("result", toolCallId: "call_1", name: "tool"),
            .other(role: "critic", content: "review", name: "c"),
        ]
        for message in legacyMessages {
            let legacyValue = try value(message)
            #expect(ChatCompletionRequestMessage(message).jsonValue == legacyValue)
        }
    }

    @Test func chatCompletionRequestEncodesFocusedAndBridgedParametersFlat() async throws {
        let focused = ChatCompletionRequest(
            model: "gpt-5.6-sol",
            messages: [.user(parts: [.text("hello")])],
            promptCacheOptions: .init(mode: .explicit, ttl: .m30)
        )
        let focusedJSON = try object(focused)
        #expect(Set(focusedJSON.keys) == ["model", "messages", "prompt_cache_options"])
        #expect(focusedJSON["model"] as? String == "gpt-5.6-sol")
        #expect(focusedJSON["parameters"] == nil)
        #expect(focusedJSON["options"] == nil)
        #expect(focusedJSON["stream"] == nil)

        let legacy = ChatCompletionCreateParams(
            model: "gpt-5.6-terra",
            messages: [.user("hello")],
            temperature: 0.25,
            topP: 0.9,
            stream: false,
            maxCompletionTokens: 128,
            user: "user_123",
            reasoningEffort: .high
        )
        let bridged = ChatCompletionRequest(legacy)
        let legacyJSON = try object(legacy)
        let bridgedJSON = try object(bridged)
        #expect(legacyJSON as NSDictionary == bridgedJSON as NSDictionary)

        #expect(bridgedJSON["temperature"] as? Double == 0.25)
        #expect(bridgedJSON["top_p"] as? Double == 0.9)
        #expect(bridgedJSON["stream"] as? Bool == false)
        #expect(bridgedJSON["max_completion_tokens"] as? Int == 128)
        #expect(bridgedJSON["reasoning_effort"] as? String == "high")
        #expect(bridgedJSON["parameters"] == nil)
        #expect(bridgedJSON["options"] == nil)
    }

    @Test func responseRequestContentFactoriesEncodeExactKeysAndDetailLiterals() async throws {
        let breakpoint = PromptCacheBreakpoint()
        let cases: [(ResponseRequestContentPart, JSONValue)] = [
            (
                .inputText("hello", promptCacheBreakpoint: breakpoint),
                [
                    "type": "input_text",
                    "text": "hello",
                    "prompt_cache_breakpoint": ["mode": "explicit"],
                ]
            ),
            (
                .inputImage(
                    url: "https://example.com/image.png",
                    detail: .auto,
                    promptCacheBreakpoint: breakpoint
                ),
                [
                    "type": "input_image",
                    "image_url": "https://example.com/image.png",
                    "detail": "auto",
                    "prompt_cache_breakpoint": ["mode": "explicit"],
                ]
            ),
            (
                .inputImage(fileID: "file_image", detail: .low),
                ["type": "input_image", "file_id": "file_image", "detail": "low"]
            ),
            (
                .inputFile(
                    id: "file_doc",
                    detail: .high,
                    promptCacheBreakpoint: breakpoint
                ),
                [
                    "type": "input_file",
                    "file_id": "file_doc",
                    "detail": "high",
                    "prompt_cache_breakpoint": ["mode": "explicit"],
                ]
            ),
            (
                .inputFile(
                    data: "ZmlsZQ==",
                    filename: "doc.pdf",
                    detail: .other("future")
                ),
                [
                    "type": "input_file",
                    "file_data": "ZmlsZQ==",
                    "filename": "doc.pdf",
                    "detail": "future",
                ]
            ),
            (
                .inputFile(url: "https://example.com/doc.pdf", detail: .auto),
                [
                    "type": "input_file",
                    "file_url": "https://example.com/doc.pdf",
                    "detail": "auto",
                ]
            ),
        ]

        for (part, expected) in cases {
            #expect(part.jsonValue == expected)
            let json = try object(part)
            #expect(json["cache_control"] == nil)
        }

        let inlineFileWithoutFilename = ResponseRequestContentPart.inputFile(
            data: "ZmlsZQ=="
        )
        guard case .object(let inlineFileFields) = inlineFileWithoutFilename.jsonValue else {
            Issue.record("Expected inputFile(data:) to create a JSON object")
            return
        }
        #expect(inlineFileFields["type"] == .string("input_file"))
        #expect(inlineFileFields["file_data"] == .string("ZmlsZQ=="))
        #expect(inlineFileFields["filename"] == nil)
        let encodedInlineFile = try object(inlineFileWithoutFilename)
        #expect(encodedInlineFile["filename"] == nil)

        let imageDetails: [(ImageDetail, String)] = [
            (.auto, "auto"),
            (.low, "low"),
            (.high, "high"),
            (.other("future_image"), "future_image"),
        ]
        for (detail, literal) in imageDetails {
            let json = try object(ResponseRequestContentPart.inputImage(
                url: "https://example.com/image.png",
                detail: detail
            ))
            #expect(json["detail"] as? String == literal)
        }

        let unknown = ResponseFileDetail.other("ultra")
        let encodedUnknown = try encoder.encode(unknown)
        let decodedUnknown = try decoder.decode(
            ResponseFileDetail.self,
            from: encodedUnknown
        )
        #expect(decodedUnknown == unknown)
    }

    @Test func responseRequestContentAndInputPreserveUnknownJSONAndBridgeLegacyCases() async throws {
        let source = """
        {"type":"future_input","nested":{"values":[1,false,null,{"x":"y"}]}}
        """
        let data = Data(source.utf8)
        let expected = try JSONDecoder().decode(JSONValue.self, from: data)
        let decoded = try decoder.decode(ResponseRequestContentPart.self, from: data)
        #expect(decoded.jsonValue == expected)
        let encodedDecoded = try encoder.encode(decoded)
        let roundTrippedDecoded = try JSONDecoder().decode(
            JSONValue.self,
            from: encodedDecoded
        )
        #expect(roundTrippedDecoded == expected)

        let messages = [
            ResponseInputMessage.user("hello"),
            ResponseInputMessage.user(parts: [
                .inputText("look"),
                .inputImage(fileId: "file_image", detail: .other("future")),
            ]),
            ResponseInputMessage.system("system"),
            ResponseInputMessage.developer("developer"),
        ]
        for message in messages {
            let legacyValue = try value(message)
            #expect(ResponseRequestMessage(message).jsonValue == legacyValue)
        }

        let items: [ResponseInputItem] = [
            .message(.user("hello")),
            .functionCallOutput(.init(callId: "call_1", output: "done")),
            .functionCall(.init(callId: "call_1", name: "lookup", arguments: "{}")),
            .itemReference(.init(id: "item_1")),
        ]
        for item in items {
            let legacyValue = try value(item)
            #expect(ResponseRequestInputItem(item).jsonValue == legacyValue)
        }

        let inputs: [ResponseInput] = [
            .text("hello"),
            .messages(messages),
            .items(items),
        ]
        for input in inputs {
            let legacyValue = try value(input)
            #expect(ResponseRequestInput(input).jsonValue == legacyValue)
        }
    }

    @Test func responseRequestInputImageDefaultsAndLegacyBridgeEncodeRequiredDetail() async throws {
        let defaultURLImage = ResponseRequestContentPart.inputImage(
            url: "https://example.com/default.png"
        )
        #expect(defaultURLImage.jsonValue == [
            "type": "input_image",
            "image_url": "https://example.com/default.png",
            "detail": "auto",
        ])

        let defaultFileImage = ResponseRequestContentPart.inputImage(fileID: "file_default")
        #expect(defaultFileImage.jsonValue == [
            "type": "input_image",
            "file_id": "file_default",
            "detail": "auto",
        ])

        let legacyURLImage = ResponseInputContentPart.inputImage(
            url: "https://example.com/legacy.png",
            detail: nil
        )
        #expect(ResponseRequestContentPart(legacyURLImage).jsonValue == [
            "type": "input_image",
            "image_url": "https://example.com/legacy.png",
            "detail": "auto",
        ])

        let legacyFileImage = ResponseInputContentPart.inputImage(
            fileId: "file_legacy",
            detail: nil
        )
        #expect(ResponseRequestContentPart(legacyFileImage).jsonValue == [
            "type": "input_image",
            "file_id": "file_legacy",
            "detail": "auto",
        ])

        let explicitDetails: [(ImageDetail, String)] = [
            (.high, "high"),
            (.other("future_image"), "future_image"),
        ]
        for (detail, literal) in explicitDetails {
            let part = ResponseRequestContentPart.inputImage(
                url: "https://example.com/explicit.png",
                detail: detail
            )
            guard case .object(let fields) = part.jsonValue else {
                Issue.record("Expected inputImage(url:) to create a JSON object")
                return
            }
            #expect(fields["detail"] == .string(literal))
        }
    }

    @Test func responseReasoningSummaryContentRequiresAndEncodesTextExactly() async throws {
        let makeSummary: (String) -> ResponseReasoningSummaryContent =
            ResponseReasoningSummaryContent.init(text:)
        let summary = makeSummary("required summary")
        let requiredText: String = summary.text

        #expect(requiredText == "required summary")
        #expect(try value(summary) == [
            "type": "summary_text",
            "text": "required summary",
        ])
    }

    @Test func responseReasoningSummaryContentRejectsMissingTextAndInvalidDiscriminator() async throws {
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(
                ResponseReasoningSummaryContent.self,
                from: Data(#"{"type":"summary_text"}"#.utf8)
            )
        }
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(
                ResponseReasoningSummaryContent.self,
                from: Data(#"{"type":"summary_text","text":null}"#.utf8)
            )
        }
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(
                ResponseReasoningSummaryContent.self,
                from: Data(#"{"type":"reasoning_text","text":"wrong type"}"#.utf8)
            )
        }
    }

    @Test func responseReasoningSummaryDecodesMissingOrNullText() async throws {
        let missingText = try decoder.decode(
            ResponseReasoningSummary.self,
            from: Data(#"{"type":"summary_text"}"#.utf8)
        )
        #expect(missingText.type == "summary_text")
        #expect(missingText.text == nil)

        let nullText = try decoder.decode(
            ResponseReasoningSummary.self,
            from: Data(#"{"type":"summary_text","text":null}"#.utf8)
        )
        #expect(nullText.type == "summary_text")
        #expect(nullText.text == nil)
    }

    @Test func responseReasoningAndCompactionFactoriesEncodeEncryptedContentExactly() async throws {
        let reasoningContent = ResponseReasoningContent(text: "private reasoning")
        #expect(try value(reasoningContent) == [
            "type": "reasoning_text",
            "text": "private reasoning",
        ])

        let reasoning = ResponseReasoningInputItem(
            id: "rs_123",
            summary: [.init(text: "summary")],
            content: [reasoningContent],
            encryptedContent: "enc_reasoning",
            status: "completed"
        )
        let expectedReasoning: JSONValue = [
            "type": "reasoning",
            "id": "rs_123",
            "summary": [["type": "summary_text", "text": "summary"]],
            "content": [["type": "reasoning_text", "text": "private reasoning"]],
            "encrypted_content": "enc_reasoning",
            "status": "completed",
        ]
        #expect(try value(reasoning) == expectedReasoning)

        let reasoningItem = ResponseRequestInputItem(reasoning: reasoning)
        #expect(reasoningItem.jsonValue == expectedReasoning)

        let compaction = ResponseCompactionInputItem(
            encryptedContent: "enc_compaction",
            id: "cmp_123"
        )
        let expectedCompaction: JSONValue = [
            "type": "compaction",
            "encrypted_content": "enc_compaction",
            "id": "cmp_123",
        ]
        #expect(try value(compaction) == expectedCompaction)

        let compactionItem = ResponseRequestInputItem(compaction: compaction)
        #expect(compactionItem.jsonValue == expectedCompaction)

        let requestInput = ResponseRequestInput.items([reasoningItem, compactionItem])
        let roundTrip = try decoder.decode(
            ResponseRequestInput.self,
            from: encoder.encode(requestInput)
        )
        #expect(roundTrip == requestInput)
    }

    @Test func strictReasoningAndCompactionTypesRejectMismatchedDiscriminators() async throws {
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(
                ResponseReasoningContent.self,
                from: Data(#"{"type":"summary_text","text":"wrong type"}"#.utf8)
            )
        }
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(
                ResponseReasoningInputItem.self,
                from: Data(#"{"type":"message","id":"rs_123","summary":[]}"#.utf8)
            )
        }
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(
                ResponseCompactionInputItem.self,
                from: Data(#"{"type":"reasoning","encrypted_content":"encrypted"}"#.utf8)
            )
        }
    }

    @Test func reasoningConfigEncodesAllExactKeysAndPreservesLegacyInitializer() async throws {
        let legacy = ReasoningConfig(effort: "high")
        let legacyJSON = try object(legacy)
        #expect(legacyJSON as NSDictionary == ["effort": "high"] as NSDictionary)

        let full = ReasoningConfig.full(
            effort: "xhigh",
            context: .allTurns,
            generateSummary: .concise,
            mode: "future_mode",
            summary: .detailed
        )
        let json = try object(full)
        #expect(Set(json.keys) == [
            "effort", "context", "generate_summary", "mode", "summary",
        ])
        #expect(json["effort"] as? String == "xhigh")
        #expect(json["context"] as? String == "all_turns")
        #expect(json["generate_summary"] as? String == "concise")
        #expect(json["mode"] as? String == "future_mode")
        #expect(json["summary"] as? String == "detailed")

        let unknownData = Data(
            #"{"effort":"future_effort","context":"future_context","generate_summary":"future_generate","mode":"future_mode","summary":"future_summary"}"#.utf8
        )
        let unknown = try decoder.decode(ReasoningConfig.self, from: unknownData)
        #expect(unknown.effort == "future_effort")
        #expect(unknown.context == .other("future_context"))
        #expect(unknown.generateSummary == .other("future_generate"))
        #expect(unknown.mode == "future_mode")
        #expect(unknown.summary == .other("future_summary"))
        let encodedUnknown = try encoder.encode(unknown)
        let roundTrippedUnknown = try JSONDecoder().decode(
            JSONValue.self,
            from: encodedUnknown
        )
        let expectedUnknown = try JSONDecoder().decode(JSONValue.self, from: unknownData)
        #expect(roundTrippedUnknown == expectedUnknown)
    }

    @Test func responseEchoDecodesExpandedReasoningAndUnknownTypedValues() async throws {
        let fixture = """
        {
          "id":"resp_reasoning",
          "object":"response",
          "created_at":123,
          "model":"gpt-5.6-luna",
          "output":[],
          "status":"completed",
          "prompt_cache_key":"cache_key",
          "prompt_cache_options":{"mode":"future_mode","ttl":"future_ttl"},
          "reasoning":{
            "effort":"future_effort",
            "context":"future_context",
            "generate_summary":"future_generate",
            "mode":"future_reasoning_mode",
            "summary":"future_summary"
          },
          "service_tier":"priority"
        }
        """
        let response = try decoder.decode(Response.self, from: Data(fixture.utf8))
        #expect(response.model == "gpt-5.6-luna")
        #expect(response.promptCacheKey == "cache_key")
        #expect(response.promptCacheOptions?.mode == .other("future_mode"))
        #expect(response.promptCacheOptions?.ttl == .other("future_ttl"))
        #expect(response.reasoning?.effort == "future_effort")
        #expect(response.reasoning?.context == .other("future_context"))
        #expect(response.reasoning?.generateSummary == .other("future_generate"))
        #expect(response.reasoning?.mode == "future_reasoning_mode")
        #expect(response.reasoning?.summary == .other("future_summary"))
        #expect(response.serviceTier == .priority)

        let roundTrip = try decoder.decode(Response.self, from: encoder.encode(response))
        #expect(roundTrip.reasoning?.context == .other("future_context"))
        #expect(roundTrip.reasoning?.summary == .other("future_summary"))
    }

    @Test func responsePromptCacheEchoRequiresModeAndTTL() async throws {
        let validFixture = """
        {
          "id":"resp_cache",
          "object":"response",
          "model":"gpt-5.6-sol",
          "output":[],
          "status":"completed",
          "prompt_cache_options":{"mode":"explicit","ttl":"30m"}
        }
        """
        let response = try decoder.decode(Response.self, from: Data(validFixture.utf8))
        #expect(response.promptCacheOptions?.mode == .explicit)
        #expect(response.promptCacheOptions?.ttl == .m30)

        let malformedOptions = [
            #"{"mode":"explicit"}"#,
            #"{"ttl":"30m"}"#,
        ]
        for options in malformedOptions {
            let malformedFixture = """
            {
              "id":"resp_cache",
              "object":"response",
              "model":"gpt-5.6-sol",
              "output":[],
              "status":"completed",
              "prompt_cache_options":\(options)
            }
            """
            do {
                _ = try decoder.decode(
                    Response.self,
                    from: Data(malformedFixture.utf8)
                )
                Issue.record("Expected malformed prompt-cache echo to fail decoding")
            } catch {
                // Expected: response echoes require both mode and ttl.
            }
        }
    }

    @Test func responseCreateRequestAndWebSocketEnvelopeStayFlatAndExact() async throws {
        let options = ResponseCreateOptions(
            instructions: "Be concise",
            maxOutputTokens: 64,
            store: false,
            metadata: ["source": "test"],
            reasoning: .full(context: .currentTurn, summary: .auto),
            promptCacheKey: "cache_key",
            promptCacheOptions: .init(mode: .implicit, ttl: .m30)
        )

        for model in ["gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna"] {
            let request = ResponseCreateRequest(
                model: model,
                input: .text("hello"),
                options: options
            )
            let json = try object(request)
            #expect(json["model"] as? String == model)
            #expect(json["options"] == nil)
            #expect(json["stream"] == nil)
            #expect(json["instructions"] as? String == "Be concise")
            #expect(json["prompt_cache_key"] as? String == "cache_key")
            #expect(json["prompt_cache_options"] != nil)

            let streaming = try object(ResponseCreateRequestStreamingBody(request: request))
            #expect(streaming["stream"] as? Bool == true)
            #expect(streaming["options"] == nil)

            let websocket = try object(ResponseWebSocketCreateRequest(request: request))
            #expect(websocket["type"] as? String == "response.create")
            #expect(websocket["model"] as? String == model)
            #expect(websocket["generate"] == nil)
            #expect(websocket["stream"] == nil)
            #expect(websocket["background"] == nil)
            #expect(websocket["options"] == nil)

            let websocketCacheOptions = try #require(
                websocket["prompt_cache_options"] as? [String: Any]
            )
            let websocketReasoning = try #require(
                websocket["reasoning"] as? [String: Any]
            )
            #expect(websocket["prompt_cache_key"] as? String == "cache_key")
            #expect(websocketCacheOptions["mode"] as? String == "implicit")
            #expect(websocketCacheOptions["ttl"] as? String == "30m")
            #expect(websocketReasoning["context"] as? String == "current_turn")
            #expect(websocketReasoning["summary"] as? String == "auto")
        }
    }

    @Test func requestWebSocketEnvelopeOmitsGenerateWhileLegacyEventRetainsIt() async throws {
        let model = "gpt-5.6-sol"
        let request = ResponseCreateRequest(
            model: model,
            input: .text("hello")
        )
        let requestEnvelope = try object(
            ResponseWebSocketCreateRequest(request: request)
        )
        let legacyEvent = try object(ResponsesClientEvent(
            model: model,
            input: .text("hello"),
            generate: false
        ))

        #expect(requestEnvelope["type"] as? String == "response.create")
        #expect(requestEnvelope["model"] as? String == model)
        #expect(requestEnvelope["generate"] == nil)
        #expect(legacyEvent["type"] as? String == "response.create")
        #expect(legacyEvent["model"] as? String == model)
        #expect(legacyEvent["generate"] as? Bool == false)
    }

    @Test func responseCreateRequestInputInitializersStayUnambiguousAndWireEquivalent() async throws {
        let primaryTextRequest = ResponseCreateRequest(
            model: "gpt-5.6-sol",
            input: .text("hi")
        )
        let primaryMessagesRequest = ResponseCreateRequest(
            model: "gpt-5.6-sol",
            input: .messages([])
        )
        let primaryItemsRequest = ResponseCreateRequest(
            model: "gpt-5.6-sol",
            input: .items([])
        )
        let legacyTextRequest = ResponseCreateRequest(
            model: "gpt-5.6-sol",
            legacyInput: ResponseInput.text("hi")
        )

        let primaryTextValue = try value(primaryTextRequest)
        let legacyTextValue = try value(legacyTextRequest)
        let messagesJSON = try object(primaryMessagesRequest)
        let itemsJSON = try object(primaryItemsRequest)
        let messagesInput = try #require(messagesJSON["input"] as? [Any])
        let itemsInput = try #require(itemsJSON["input"] as? [Any])

        #expect(primaryTextValue == legacyTextValue)
        #expect(messagesInput.isEmpty)
        #expect(itemsInput.isEmpty)
        #expect(Set(messagesJSON.keys) == ["model", "input"])
        #expect(Set(itemsJSON.keys) == ["model", "input"])
    }

    @Test func compactRequestEncodesCacheFieldsAndCannotEmitReasoning() async throws {
        let request = ResponseCompactRequest(
            model: "gpt-5.6-terra",
            input: .items([
                .init(compaction: .init(encryptedContent: "enc_input"))
            ]),
            instructions: "compact",
            previousResponseId: "resp_previous",
            promptCacheKey: "cache_key",
            promptCacheOptions: .init(mode: .explicit, ttl: .m30),
            promptCacheRetention: .h24,
            serviceTier: .priority
        )
        let json = try object(request)
        #expect(Set(json.keys) == [
            "model", "input", "instructions", "previous_response_id",
            "prompt_cache_key", "prompt_cache_options",
            "prompt_cache_retention", "service_tier",
        ])
        #expect(json["model"] as? String == "gpt-5.6-terra")
        #expect(json["reasoning"] == nil)
        #expect(json["options"] == nil)
        #expect(json["prompt_cache_key"] as? String == "cache_key")
        #expect(json["prompt_cache_retention"] as? String == "24h")
        let cache = try #require(json["prompt_cache_options"] as? [String: Any])
        #expect(cache["mode"] as? String == "explicit")
        #expect(cache["ttl"] as? String == "30m")
    }

    @Test func compactResponsePreservesEncryptedCompactionContentOnRoundTrip() async throws {
        let fixture = """
        {
          "id":"resp_compact",
          "object":"response.compaction",
          "created_at":123,
          "output":[{
            "type":"compaction",
            "id":"cmp_123",
            "encrypted_content":"enc_compacted_state",
            "created_by":"service"
          }],
          "usage":{"input_tokens":10,"output_tokens":2,"total_tokens":12}
        }
        """
        let response = try decoder.decode(CompactedResponse.self, from: Data(fixture.utf8))
        let item = try #require(response.output.first)
        #expect(response.object == "response.compaction")
        #expect(item.type == "compaction")
        #expect(item.encryptedContent == "enc_compacted_state")
        #expect(item.createdBy == "service")

        let roundTrip = try decoder.decode(
            CompactedResponse.self,
            from: encoder.encode(response)
        )
        #expect(roundTrip.output.first?.encryptedContent == "enc_compacted_state")
        #expect(roundTrip.output.first?.createdBy == "service")
    }

    @Test func responseStreamReasoningSummaryFieldsDecodeExactly() async throws {
        let fixture = """
        {
          "type":"response.reasoning_summary_text.delta",
          "delta":"summary",
          "output_index":1,
          "summary_index":2,
          "status":"in_progress",
          "stream_id":"lane_123",
          "sequence_number":7
        }
        """
        let event = try decoder.decode(ResponseStreamEvent.self, from: Data(fixture.utf8))
        #expect(event.type == "response.reasoning_summary_text.delta")
        #expect(event.delta == "summary")
        #expect(event.outputIndex == 1)
        #expect(event.summaryIndex == 2)
        #expect(event.status == "in_progress")
        #expect(event.streamId == "lane_123")
        #expect(event.sequenceNumber == 7)
    }

    @Test func responseWebSocketTerminalEventsDecodeCleanupSignalsExactly() async throws {
        for type in ["response.completed", "response.failed", "response.incomplete"] {
            let fixture = #"{"type":"\#(type)","sequence_number":1}"#
            let event = try decoder.decode(
                ResponseStreamEvent.self,
                from: Data(fixture.utf8)
            )
            #expect(event.type == type)
            #expect(event.sequenceNumber == 1)
        }
    }

    #if canImport(Darwin)
    @Test func responseWebSocketClearsInFlightAfterSequentialSendFailures() async throws {
        let client = OpenAI(apiKey: "sk-test-gpt56")
        let socket: ResponsesWebSocket = client.responses.connectWebSocket()
        let request = ResponseCreateRequest(
            model: "gpt-5.6-sol",
            input: .text("hello")
        )
        var errors: [OpenAIError] = []

        for _ in 0..<2 {
            do {
                _ = try await socket.create(request: request)
                Issue.record("Expected create on an unconnected WebSocket to fail")
            } catch let error as OpenAIError {
                errors.append(error)
            } catch {
                Issue.record("Expected OpenAIError, received \(error)")
            }
        }

        #expect(errors == [
            .connectionError(message: "WebSocket is not connected"),
            .connectionError(message: "WebSocket is not connected"),
        ])
    }
    #endif

    @Test func protectedLegacyEnumCaseAritiesRemainSourceCompatible() async throws {
        let contentParts: [ChatCompletionContentPart] = [
            .text("text"),
            .imageURL(.init(url: "https://example.com/image.png")),
            .other(type: "future"),
        ]
        for part in contentParts {
            switch part {
            case .text(let text):
                #expect(text == "text")
            case .imageURL(let image):
                #expect(image.url.hasPrefix("https://"))
            case .other(let type):
                #expect(type == "future")
            @unknown default:
                Issue.record("A protected ChatCompletionContentPart case was added")
            }
        }

        let messages: [ChatCompletionMessage] = [
            .system("s", name: nil),
            .user("u", name: nil),
            .userParts([], name: nil),
            .assistant(nil, name: nil, refusal: nil, toolCalls: nil),
            .tool("t", toolCallId: "call", name: nil),
            .other(role: "other", content: nil, name: nil),
        ]
        for message in messages {
            switch message {
            case .system, .user, .userParts, .assistant, .tool, .other:
                break
            @unknown default:
                Issue.record("A protected ChatCompletionMessage case was added")
            }
        }

        let inputs: [ResponseInput] = [.text("t"), .messages([]), .items([])]
        for input in inputs {
            switch input {
            case .text, .messages, .items:
                break
            @unknown default:
                Issue.record("A protected ResponseInput case was added")
            }
        }

        let items: [ResponseInputItem] = [
            .message(.user("u")),
            .functionCallOutput(.init(callId: "c", output: "o")),
            .functionCall(.init(callId: "c", name: "n", arguments: "{}")),
            .itemReference(.init(id: "i")),
        ]
        for item in items {
            switch item {
            case .message, .functionCallOutput, .functionCall, .itemReference:
                break
            @unknown default:
                Issue.record("A protected ResponseInputItem case was added")
            }
        }

        _ = ChatCompletionCreateParams(model: "gpt-4o", messages: [.user("hello")])
        _ = ReasoningConfig(effort: "high")
        _ = ResponseInputMessage(role: "user", content: "hello")
        _ = ResponseCreateRequest(model: "gpt-4o", input: .text("hello"))
    }
}
