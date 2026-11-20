import Foundation
import Testing
@testable import SwiftOpenAI

enum DecisionsFixtures {
    static let usage = """
    {"input_tokens":1200,"input_tokens_details":{"cached_tokens":640,"cache_write_tokens":128},
     "output_tokens":16,"output_tokens_details":{"reasoning_tokens":8},"total_tokens":1216}
    """

    static let response = """
    {
      "model":"gpt-6-luna",
      "answers":[
        {"type":"predicate","name":"damaged","probability":0.95},
        {"type":"choice","name":"department","choice":"billing","confidence":0.9,
         "probabilities":[{"value":"billing","probability":0.8},{"value":"other","probability":0.2}]},
        {"type":"choice","name":"verified","choice":true,"confidence":0.8,
         "probabilities":[{"value":true,"probability":0.75},{"value":"true","probability":0.25}]},
        {"type":"score","name":"severity","score":1.1,"confidence":0.85,
         "probabilities":[{"label":"Cosmetic","value":0,"probability":0.1},
                          {"label":"Workaround","value":1,"probability":0.7},
                          {"label":"Blocked","value":2,"probability":0.2}]},
        {"type":"refusal","name":null},
        {"type":"future_answer","name":"future","ExtraPayload":{"KeepMyKey":[true,7,null]}}
      ],
      "usage":\(usage)
    }
    """
}

@Suite struct DecisionTypesTests {
    private func json(_ string: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(string.utf8))
    }

    private func expectWire<T: Codable & Equatable>(_ value: T, _ expected: String) throws {
        let data = try HTTPClient.encoder.encode(value)
        #expect(try JSONDecoder().decode(JSONValue.self, from: data) == json(expected))
        #expect(try HTTPClient.decoder.decode(T.self, from: data) == value)
    }

    @Test func textInputAndAllMessageRolesMatchWireFixtures() throws {
        try expectWire(DecisionInput.text("Shared evidence"), #""Shared evidence""#)
        try expectWire(DecisionInput.text(""), #""""#)
        let input = DecisionInput.items([
            .system("System instructions"),
            .developer("Developer instructions"),
            .user("A damaged item"),
            .assistant("Let me inspect it"),
            .system(parts: [DecisionInputText("Shared reference", promptCacheBreakpoint: .init())]),
            .developer(parts: [DecisionInputText("Text only")]),
            .user(parts: [.text("Evidence"), .json(["CustomerID": "Case_A", "events": [2, 1]])]),
            .assistant(parts: [.text("An observation"), .refusal("Cannot answer")], phase: "final_answer"),
            .assistant("Checking", phase: "commentary"),
        ])
        try expectWire(input, """
        [
          {"type":"message","role":"system","content":"System instructions"},
          {"type":"message","role":"developer","content":"Developer instructions"},
          {"type":"message","role":"user","content":"A damaged item"},
          {"type":"message","role":"assistant","content":"Let me inspect it"},
          {"type":"message","role":"system","content":[{"type":"input_text","text":"Shared reference",
            "prompt_cache_breakpoint":{"mode":"explicit"}}]},
          {"type":"message","role":"developer","content":[{"type":"input_text","text":"Text only"}]},
          {"type":"message","role":"user","content":[{"type":"input_text","text":"Evidence"},
            {"type":"input_json","data":{"CustomerID":"Case_A","events":[2,1]}}]},
          {"type":"message","role":"assistant","phase":"final_answer","content":[
            {"type":"output_text","text":"An observation"},{"type":"refusal","refusal":"Cannot answer"}]},
          {"type":"message","role":"assistant","phase":"commentary","content":"Checking"}
        ]
        """)
    }

    @Test func sharedContentPreservesImagesJSONAndCacheBoundaries() throws {
        let parts: [(DecisionInputPart, String)] = [
            (.text("Text", promptCacheBreakpoint: .init()),
             #"{"type":"input_text","text":"Text","prompt_cache_breakpoint":{"mode":"explicit"}}"#),
            (.image(url: "https://example.com/reference.jpg"),
             #"{"type":"input_image","image_url":"https://example.com/reference.jpg"}"#),
            (.image(url: "data:image/png;base64,AQID", detail: .original, promptCacheBreakpoint: .init()),
             #"{"type":"input_image","image_url":"data:image/png;base64,AQID","detail":"original","prompt_cache_breakpoint":{"mode":"explicit"}}"#),
            (.json(["camelCase": true, "snake_key": nil, "Nested": ["KeepMe": 42]]),
             #"{"type":"input_json","data":{"camelCase":true,"snake_key":null,"Nested":{"KeepMe":42}}}"#),
            (.json([["ID": 2], ["ID": 1]]),
             #"{"type":"input_json","data":[{"ID":2},{"ID":1}]}"#),
        ]
        for (part, expected) in parts {
            try expectWire(part, expected)
        }
        try expectWire(DecisionInputText("Direct text"), #"{"type":"input_text","text":"Direct text"}"#)
    }

    @Test(arguments: [ImageDetail.auto, .low, .high, .original, .other("future_detail")])
    func imageDetailReusesTheSharedType(_ detail: ImageDetail) throws {
        let encodedDetail = try HTTPClient.encoder.encode(detail)
        let expectedDetail = try JSONDecoder().decode(JSONValue.self, from: encodedDetail)
        let part = DecisionInputPart.image(url: "https://example.com/image.jpg", detail: detail)
        let expected: JSONValue = ["type": "input_image", "image_url": "https://example.com/image.jpg", "detail": expectedDetail]
        #expect(try JSONDecoder().decode(JSONValue.self, from: HTTPClient.encoder.encode(part)) == expected)
    }

    @Test func questionPartsHaveNoMessageWrappersOrCachingFields() throws {
        let parts: [DecisionQuestionInputPart] = [
            .text("Compare this image"),
            .image(url: "https://example.com/candidate.jpg", detail: .high),
            .json(["expected": true]),
            .json([["ID": 1], ["ID": 2]]),
        ]
        try expectWire(DecisionInstructions.parts(parts), """
        [{"type":"input_text","text":"Compare this image"},
         {"type":"input_image","image_url":"https://example.com/candidate.jpg","detail":"high"},
         {"type":"input_json","data":{"expected":true}},
         {"type":"input_json","data":[{"ID":1},{"ID":2}]}]
        """)
        for part in parts {
            if case .object(let fields) = part.jsonValue {
                #expect(fields["prompt_cache_breakpoint"] == nil)
                #expect(fields["role"] == nil)
            } else {
                Issue.record("Expected an object content part")
            }
        }
        try expectWire(DecisionQuestionInputPart.image(url: "data:image/png;base64,AQID"),
                       #"{"type":"input_image","image_url":"data:image/png;base64,AQID"}"#)
    }

    @Test func completeToolHistoryMatchesWireFixtures() throws {
        let input = DecisionInput.items([
            .functionCall(callID: "fc1", name: "lookup", arguments: #"{"ID":1}"#),
            .functionCallOutput(callID: "fc1", output: "Found"),
            .functionCall(callID: "fc2", name: "lookup", arguments: "{}", id: "item_2", namespace: "inventory", status: "completed"),
            .functionCallOutput(callID: "fc2", parts: [
                .text("Result", promptCacheBreakpoint: .init()),
                .image(url: "https://example.com/result.jpg"),
            ], id: "result_2", status: "completed"),
            .customToolCall(callID: "cc1", name: "inspect", input: "inspect item"),
            .customToolCallOutput(callID: "cc1", output: "Intact"),
            .customToolCall(callID: "cc2", name: "inspect", input: "inspect photo", id: "item_3", namespace: "visual", status: "in_progress"),
            .customToolCallOutput(callID: "cc2", parts: [
                .text("Photo"),
                .image(url: "data:image/png;base64,AQID", detail: .low, promptCacheBreakpoint: .init()),
            ], id: "result_3", status: "incomplete"),
        ])
        try expectWire(input, #"""
        [
          {"type":"function_call","call_id":"fc1","name":"lookup","arguments":"{\"ID\":1}"},
          {"type":"function_call_output","call_id":"fc1","output":"Found"},
          {"type":"function_call","call_id":"fc2","name":"lookup","arguments":"{}",
           "id":"item_2","namespace":"inventory","status":"completed"},
          {"type":"function_call_output","call_id":"fc2","output":[
            {"type":"input_text","text":"Result","prompt_cache_breakpoint":{"mode":"explicit"}},
            {"type":"input_image","image_url":"https://example.com/result.jpg"}],"id":"result_2","status":"completed"},
          {"type":"custom_tool_call","call_id":"cc1","name":"inspect","input":"inspect item"},
          {"type":"custom_tool_call_output","call_id":"cc1","output":"Intact"},
          {"type":"custom_tool_call","call_id":"cc2","name":"inspect","input":"inspect photo",
           "id":"item_3","namespace":"visual","status":"in_progress"},
          {"type":"custom_tool_call_output","call_id":"cc2","output":[
            {"type":"input_text","text":"Photo"},
            {"type":"input_image","image_url":"data:image/png;base64,AQID","detail":"low",
             "prompt_cache_breakpoint":{"mode":"explicit"}}],"id":"result_3","status":"incomplete"}
        ]
        """#)
    }

    @Test func allQuestionTypesEncodeTheirOwnFieldsAndOptionalNames() throws {
        try expectWire(DecisionQuestion.predicate(instructions: .text("Is damaged?")),
                       #"{"type":"predicate","instructions":"Is damaged?"}"#)
        try expectWire(DecisionQuestion.choice(
            instructions: .parts([.text("Choose a category"), .image(url: "https://example.com/option.jpg")]),
            choices: [.init(value: true, description: "Verified"), .init(value: "true")],
            name: "category"
        ), """
        {"type":"choice","name":"category","instructions":[
          {"type":"input_text","text":"Choose a category"},
          {"type":"input_image","image_url":"https://example.com/option.jpg"}],
         "choices":[{"value":true,"description":"Verified"},{"value":"true"}]}
        """)
        try expectWire(DecisionQuestion.score(
            instructions: .parts([.json(["criterion": "severity"])]),
            levels: [.init(label: "Minor"), .init(label: "Major", description: "Work is blocked")],
            name: "severity"
        ), """
        {"type":"score","name":"severity","instructions":[{"type":"input_json","data":{"criterion":"severity"}}],
         "levels":[{"label":"Minor"},{"label":"Major","description":"Work is blocked"}]}
        """)
        try expectWire(DecisionChoiceOption(value: false), #"{"value":false}"#)
        try expectWire(DecisionChoiceOption(value: "other", description: "Fallback"), #"{"value":"other","description":"Fallback"}"#)
        try expectWire(DecisionScoreLevel(label: "Minor"), #"{"label":"Minor"}"#)
        try expectWire(DecisionScoreLevel(label: "Major", description: "Blocked"), #"{"label":"Major","description":"Blocked"}"#)
    }

    @Test func rawJSONInitializersRetainUnknownFieldsAndKeySpelling() throws {
        let fixture = #"{"type":"future_part","CustomField":{"KeepMyKey":[3,true,null]}}"#
        let value = try json(fixture)
        try expectWire(DecisionInput(jsonValue: value), fixture)
        try expectWire(DecisionInputText(jsonValue: value), fixture)
        try expectWire(DecisionInputPart(jsonValue: value), fixture)
        try expectWire(DecisionQuestionInputPart(jsonValue: value), fixture)
        try expectWire(DecisionToolOutputPart(jsonValue: value), fixture)
        try expectWire(DecisionAssistantContentPart(jsonValue: value), fixture)
        try expectWire(DecisionInputItem(jsonValue: value), fixture)
        try expectWire(DecisionInstructions(jsonValue: value), fixture)
        try expectWire(DecisionQuestion(jsonValue: value), fixture)
    }

    @Test func stringAndBooleanChoicesRemainDistinct() throws {
        let values: [DecisionChoiceValue] = ["true", true, "false", false, ""]
        let fixtures = [#""true""#, "true", #""false""#, "false", #""""#]
        for (value, fixture) in zip(values, fixtures) {
            try expectWire(value, fixture)
        }
        #expect(DecisionChoiceValue.string("true") != .bool(true))
        #expect(Set(values).count == values.count)
    }

    @Test(arguments: ["1", "1.5", "null", "[]", "{}"])
    func invalidChoiceValuesAreRejected(_ fixture: String) throws {
        #expect(throws: DecodingError.self) {
            try HTTPClient.decoder.decode(DecisionChoiceValue.self, from: Data(fixture.utf8))
        }
    }

    @Test func mixedAnswersPreserveOrderTypesRefusalsAndAllUsageFields() throws {
        let result = try HTTPClient.decoder.decode(Decision.self, from: Data(DecisionsFixtures.response.utf8))
        #expect(result.model == "gpt-6-luna")
        #expect(result.answers.map(\.name) == ["damaged", "department", "verified", "severity", nil, "future"])
        #expect(result.answers[0] == .predicate(name: "damaged", probability: 0.95))
        #expect(result.answers[1] == .choice(name: "department", choice: "billing", confidence: 0.9, probabilities: [
            .init(value: "billing", probability: 0.8), .init(value: "other", probability: 0.2),
        ]))
        #expect(result.answers[2] == .choice(name: "verified", choice: true, confidence: 0.8, probabilities: [
            .init(value: true, probability: 0.75), .init(value: "true", probability: 0.25),
        ]))
        #expect(result.answers[3] == .score(name: "severity", score: 1.1, confidence: 0.85, probabilities: [
            .init(label: "Cosmetic", value: 0, probability: 0.1),
            .init(label: "Workaround", value: 1, probability: 0.7),
            .init(label: "Blocked", value: 2, probability: 0.2),
        ]))
        #expect(result.answers[4] == .refusal(name: nil))
        let futureAnswer = try json(
            #"{"type":"future_answer","name":"future","ExtraPayload":{"KeepMyKey":[true,7,null]}}"#
        )
        #expect(result.answers[5] == .other(futureAnswer))
        #expect(result.usage == DecisionUsage(
            inputTokens: 1200,
            inputTokensDetails: .init(cachedTokens: 640, cacheWriteTokens: 128),
            outputTokens: 16,
            outputTokensDetails: .init(reasoningTokens: 8),
            totalTokens: 1216
        ))
        try expectWire(result, DecisionsFixtures.response)
        try expectWire(Decision(model: result.model, answers: result.answers, usage: result.usage), DecisionsFixtures.response)
    }

    @Test func nullQuestionNamesAreEncodedExplicitlyForEveryKnownAnswer() throws {
        let answers: [DecisionAnswer] = [
            .predicate(name: nil, probability: 0),
            .choice(name: nil, choice: false, confidence: 1, probabilities: []),
            .score(name: nil, score: 0, confidence: 1, probabilities: []),
            .refusal(name: nil),
        ]
        for answer in answers {
            #expect(answer.name == nil)
            let data = try HTTPClient.encoder.encode(answer)
            let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            #expect(object["name"] is NSNull)
            #expect(try HTTPClient.decoder.decode(DecisionAnswer.self, from: data) == answer)
        }
        try expectWire(DecisionAnswer.refusal(name: "blocked"), #"{"type":"refusal","name":"blocked"}"#)
        #expect(DecisionAnswer.refusal(name: "blocked").name == "blocked")
    }

    @Test func knownAnswersDecodeWithOmittedNullAndNamedQuestionNames() throws {
        let fixtures: [(String, DecisionAnswer)] = [
            (#"{"type":"predicate","probability":0.5}"#, .predicate(name: nil, probability: 0.5)),
            (#"{"type":"choice","choice":true,"confidence":0.9,"probabilities":[]}"#, .choice(name: nil, choice: true, confidence: 0.9, probabilities: [])),
            (#"{"type":"score","score":1.5,"confidence":0.8,"probabilities":[]}"#, .score(name: nil, score: 1.5, confidence: 0.8, probabilities: [])),
            (#"{"type":"refusal"}"#, .refusal(name: nil)),
            (#"{"type":"predicate","name":null,"probability":0.5}"#, .predicate(name: nil, probability: 0.5)),
            (#"{"type":"choice","name":null,"choice":true,"confidence":0.9,"probabilities":[]}"#, .choice(name: nil, choice: true, confidence: 0.9, probabilities: [])),
            (#"{"type":"score","name":null,"score":1.5,"confidence":0.8,"probabilities":[]}"#, .score(name: nil, score: 1.5, confidence: 0.8, probabilities: [])),
            (#"{"type":"refusal","name":null}"#, .refusal(name: nil)),
            (#"{"type":"predicate","name":"flag","probability":0.5}"#, .predicate(name: "flag", probability: 0.5)),
            (#"{"type":"choice","name":"selection","choice":true,"confidence":0.9,"probabilities":[]}"#, .choice(name: "selection", choice: true, confidence: 0.9, probabilities: [])),
            (#"{"type":"score","name":"rating","score":1.5,"confidence":0.8,"probabilities":[]}"#, .score(name: "rating", score: 1.5, confidence: 0.8, probabilities: [])),
            (#"{"type":"refusal","name":"blocked"}"#, .refusal(name: "blocked")),
        ]

        for (fixture, expected) in fixtures {
            #expect(try HTTPClient.decoder.decode(DecisionAnswer.self, from: Data(fixture.utf8)) == expected)
        }
    }

    @Test(arguments: [
        #"{"type":"predicate","name":null}"#,
        #"{"type":"predicate","name":"x","probability":"wrong"}"#,
        #"{"type":"choice","name":null,"choice":42,"confidence":0.9,"probabilities":[]}"#,
        #"{"type":"choice","name":null,"choice":true,"probabilities":[]}"#,
        #"{"type":"score","name":null,"score":1.1,"confidence":0.8}"#,
        #"{"type":"score","name":null,"score":1.1,"confidence":0.8,"probabilities":[{"label":"x","probability":1}]}"#,
        #"{"type":"refusal","name":42}"#,
        #"{"name":"missing_type"}"#,
        #"{"type":42,"name":null}"#,
    ])
    func malformedKnownAnswersThrowDecodingErrors(_ fixture: String) throws {
        #expect(throws: DecodingError.self) {
            try HTTPClient.decoder.decode(DecisionAnswer.self, from: Data(fixture.utf8))
        }
    }

    @Test func unknownAnswersRetainTheirPayloadAndOptionalName() throws {
        for fixture in [
            #"{"type":"future","name":null,"CustomField":[1,2]}"#,
            #"{"type":"future","CustomField":true}"#,
            #"{"type":"future","snake_key":1,"snakeKey":2,"Nested":{"KeepMyKey":true,"keep_my_key":false}}"#,
        ] {
            let answer = try HTTPClient.decoder.decode(DecisionAnswer.self, from: Data(fixture.utf8))
            let expected = try json(fixture)
            #expect(answer.name == nil)
            #expect(answer == .other(expected))
            try expectWire(answer, fixture)
        }
        #expect(DecisionAnswer.other(.null).name == nil)
        #expect(throws: DecodingError.self) {
            try HTTPClient.decoder.decode(DecisionAnswer.self, from: Data("null".utf8))
        }
    }

    @Test func multimodalPredicatesAndScoresAndTextChoicesMatchTheContract() throws {
        let instructions = DecisionInstructions.parts([
            .text("Compare against this evidence"),
            .image(url: "data:image/png;base64,AQID"),
            .json(["expected": true]),
        ])
        try expectWire(DecisionQuestion.predicate(instructions: instructions, name: "matches"), """
        {"type":"predicate","name":"matches","instructions":[
          {"type":"input_text","text":"Compare against this evidence"},
          {"type":"input_image","image_url":"data:image/png;base64,AQID"},
          {"type":"input_json","data":{"expected":true}}]}
        """)
        try expectWire(DecisionQuestion.score(
            instructions: instructions, levels: [.init(label: "No match"), .init(label: "Matches")]
        ), """
        {"type":"score","instructions":[
          {"type":"input_text","text":"Compare against this evidence"},
          {"type":"input_image","image_url":"data:image/png;base64,AQID"},
          {"type":"input_json","data":{"expected":true}}],
         "levels":[{"label":"No match"},{"label":"Matches"}]}
        """)
        try expectWire(DecisionQuestion.choice(
            instructions: .text("Is the evidence verified?"), choices: [.init(value: true), .init(value: false)]
        ), #"{"type":"choice","instructions":"Is the evidence verified?","choices":[{"value":true},{"value":false}]}"#)
        try expectWire(DecisionQuestion.score(
            instructions: .text("Rate severity"), levels: [.init(label: "Low"), .init(label: "High")], name: ""
        ), #"{"type":"score","name":"","instructions":"Rate severity","levels":[{"label":"Low"},{"label":"High"}]}"#)
    }

    @Test func cacheOptionsPreserveImplicitAndPartiallySpecifiedSettings() throws {
        let cases: [(PromptCacheOptions, String)] = [
            (.init(), "{}"),
            (.init(mode: .implicit), #"{"mode":"implicit"}"#),
            (.init(ttl: .m30), #"{"ttl":"30m"}"#),
            (.init(mode: .implicit, ttl: .m30), #"{"mode":"implicit","ttl":"30m"}"#),
        ]
        for (options, expected) in cases {
            let request = DecisionCreateRequest(
                model: "gpt-6-luna", input: .text("Evidence"),
                questions: [.predicate(instructions: .text("Relevant?"))],
                promptCacheOptions: options
            )
            let data = try HTTPClient.encoder.encode(request)
            let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let actualOptions = try #require(object["prompt_cache_options"])
            let optionsData = try JSONSerialization.data(withJSONObject: actualOptions)
            #expect(try JSONDecoder().decode(JSONValue.self, from: optionsData) == json(expected))
            #expect(object["prompt_cache_key"] == nil)
            #expect(object["safety_identifier"] == nil)
        }
    }

    @Test func emptyAnswersAndZeroUsageAreValid() throws {
        let fixture = """
        {"model":"gpt-6-luna","answers":[],"usage":{
          "input_tokens":0,"input_tokens_details":{"cached_tokens":0,"cache_write_tokens":0},
          "output_tokens":0,"output_tokens_details":{"reasoning_tokens":0},"total_tokens":0}}
        """
        let result = try HTTPClient.decoder.decode(Decision.self, from: Data(fixture.utf8))
        #expect(result.answers.isEmpty)
        #expect(result.usage.totalTokens == 0)
        try expectWire(result, fixture)
    }

    @Test func malformedResponseAndUsageFieldsAreRejected() throws {
        let original = try #require(JSONSerialization.jsonObject(with: Data(DecisionsFixtures.response.utf8)) as? [String: Any])
        let originalUsage = try #require(original["usage"] as? [String: Any])
        var fixtures: [[String: Any]] = []
        for field in ["model", "answers", "usage"] {
            var invalid = original
            invalid.removeValue(forKey: field)
            fixtures.append(invalid)
            invalid = original
            invalid[field] = NSNull()
            fixtures.append(invalid)
        }
        for field in ["input_tokens", "input_tokens_details", "output_tokens", "output_tokens_details", "total_tokens"] {
            var usage = originalUsage
            usage[field] = "wrong type"
            var invalid = original
            invalid["usage"] = usage
            fixtures.append(invalid)
        }
        for field in ["cached_tokens", "cache_write_tokens"] {
            var details = try #require(originalUsage["input_tokens_details"] as? [String: Any])
            details.removeValue(forKey: field)
            var usage = originalUsage
            usage["input_tokens_details"] = details
            var invalid = original
            invalid["usage"] = usage
            fixtures.append(invalid)
        }
        var usage = originalUsage
        usage["output_tokens_details"] = [:] as [String: Any]
        var invalid = original
        invalid["usage"] = usage
        fixtures.append(invalid)
        for fixture in fixtures {
            let data = try JSONSerialization.data(withJSONObject: fixture)
            #expect(throws: DecodingError.self) {
                try HTTPClient.decoder.decode(Decision.self, from: data)
            }
        }
    }

    @Test func requestLeavesModelAndQuestionLimitsToTheService() throws {
        let request = DecisionCreateRequest(
            model: "future-model",
            input: .text(""),
            questions: Array(repeating: .predicate(instructions: .text("Relevant?")), count: 400)
        )
        let data = try HTTPClient.encoder.encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["model"] as? String == "future-model")
        #expect((object["questions"] as? [Any])?.count == 400)
        #expect(object["prompt_cache_key"] == nil)
        #expect(object["prompt_cache_options"] == nil)
        #expect(object["safety_identifier"] == nil)
    }
}
