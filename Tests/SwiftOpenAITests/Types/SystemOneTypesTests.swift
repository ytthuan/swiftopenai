import Foundation
import Testing
@testable import SwiftOpenAI

enum SystemOneFixtures {
    static let response = """
    {
      "model":"microsoft-decision-1.1",
      "answers":{
        "team":{"type":"choice","choice":"engineering","confidence":0.99,
          "probabilities":{"billing":0.005,"engineering":0.99,"support_team":0.005}},
        "severity":{"type":"score","score":2.9,"confidence":0.9,
          "probabilities":{"0":0.0,"1":0.0,"2":0.1,"3":0.9},
          "legend":{"0":"Cosmetic","1":"Minor","2":"Major","3":"Critical"}},
        "repeat_contact":{"type":"noul","noul":0.98},
        "Future_Answer":{"type":"future_kind","Keep_Key":[true,2,null]}
      },
      "usage":{"input_tokens":120,"output_tokens":3},
      "Future_Field":{"Keep_This_Key":true}
    }
    """
}

@Suite struct SystemOneTypesTests {
    private func json(_ string: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(string.utf8))
    }

    private func expectWire<T: Codable & Equatable>(_ value: T, _ expected: String) throws {
        let data = try HTTPClient.encoder.encode(value)
        #expect(try JSONDecoder().decode(JSONValue.self, from: data) == json(expected))
        #expect(try HTTPClient.decoder.decode(T.self, from: data) == value)
    }

    @Test func stateEncodesTextJSONAndArbitraryWireValues() throws {
        try expectWire(SystemOneState.text("The payment integration still fails."), #""The payment integration still fails.""#)
        try expectWire(
            SystemOneState.json(["Customer_ID": "Case_A", "contact_count": 3, "events": ["first", "second"]]),
            #"{"Customer_ID":"Case_A","contact_count":3,"events":["first","second"]}"#
        )
        try expectWire(SystemOneState(jsonValue: ["CustomKey": true]), #"{"CustomKey":true}"#)
    }

    @Test func assetsEncodeImageAndCustomWireValues() throws {
        try expectWire(
            SystemOneAsset.image(format: "png", dataBase64: "AQID"),
            #"{"type":"image","format":"png","data_base64":"AQID"}"#
        )
        try expectWire(
            SystemOneAsset(jsonValue: ["type": "document", "Keep_Key": "abc"]),
            #"{"type":"document","Keep_Key":"abc"}"#
        )
    }

    @Test func questionsEncodeNoulChoiceScoreAndCustomWireValues() throws {
        try expectWire(
            SystemOneQuestion.noul(instructions: "Does this message convey urgency?"),
            #"{"type":"noul","instructions":"Does this message convey urgency?"}"#
        )
        let noulCriteria = SystemOneNoulCriteria(
            true: "Commits to returning money",
            false: "Makes no commitment about money"
        )
        try expectWire(noulCriteria, #"{"true":"Commits to returning money","false":"Makes no commitment about money"}"#)
        try expectWire(
            SystemOneQuestion.noul(
                instructions: "Does this reply promise a refund?",
                criteria: noulCriteria
            ),
            """
            {"type":"noul","instructions":"Does this reply promise a refund?",
             "criteria":{"true":"Commits to returning money","false":"Makes no commitment about money"}}
            """
        )
        try expectWire(
            SystemOneQuestion.choice(
                instructions: "Which team?",
                criteria: ["billing_team": "Charges", "Team_A": "Bugs"]
            ),
            #"{"type":"choice","instructions":"Which team?","criteria":{"billing_team":"Charges","Team_A":"Bugs"}}"#
        )
        try expectWire(
            SystemOneQuestion.score(
                instructions: "How severe?",
                criteria: ["Cosmetic", "Minor", "Major", "Critical"]
            ),
            #"{"type":"score","instructions":"How severe?","criteria":["Cosmetic","Minor","Major","Critical"]}"#
        )
        try expectWire(
            SystemOneQuestion(jsonValue: ["type": "custom", "Keep_Key": 1]),
            #"{"type":"custom","Keep_Key":1}"#
        )
    }

    @Test func createRequestPreservesExactKeysAndOmitsUnsetAssets() throws {
        let minimal = SystemOneCreateRequest(
            model: "Decision-1.1",
            state: .text("The payment integration still fails."),
            questions: [
                "repeat_contact": .noul(instructions: "Is this a repeat contact?"),
                "Team_A": .choice(instructions: "Route?", criteria: ["billing_ops": "Billing", "CoreEng": "Eng"]),
            ]
        )
        try expectWire(minimal, """
        {
          "model":"Decision-1.1",
          "state":"The payment integration still fails.",
          "questions":{
            "repeat_contact":{"type":"noul","instructions":"Is this a repeat contact?"},
            "Team_A":{"type":"choice","instructions":"Route?","criteria":{"billing_ops":"Billing","CoreEng":"Eng"}}
          }
        }
        """)

        let withAssets = SystemOneCreateRequest(
            model: "Decision-1.1",
            state: .text("Customer photo: image:photo.png"),
            questions: ["damaged": .noul(instructions: "Does the photo show damage?")],
            assets: ["photo.png": .image(format: "png", dataBase64: "AQID")]
        )
        try expectWire(withAssets, """
        {
          "model":"Decision-1.1",
          "state":"Customer photo: image:photo.png",
          "questions":{"damaged":{"type":"noul","instructions":"Does the photo show damage?"}},
          "assets":{"photo.png":{"type":"image","format":"png","data_base64":"AQID"}}
        }
        """)
    }

    @Test func responseAndAnswersRoundTripWithPreservedKeys() throws {
        let decoded = try HTTPClient.decoder.decode(
            SystemOneResponse.self,
            from: Data(SystemOneFixtures.response.utf8)
        )
        #expect(decoded.model == "microsoft-decision-1.1")
        #expect(decoded.usage == SystemOneUsage(inputTokens: 120, outputTokens: 3))
        #expect(decoded.answers["team"] == .choice(
            choice: "engineering",
            confidence: 0.99,
            probabilities: ["billing": 0.005, "engineering": 0.99, "support_team": 0.005]
        ))
        #expect(decoded.answers["severity"] == .score(
            score: 2.9,
            confidence: 0.9,
            probabilities: ["0": 0.0, "1": 0.0, "2": 0.1, "3": 0.9],
            legend: ["0": "Cosmetic", "1": "Minor", "2": "Major", "3": "Critical"]
        ))
        #expect(decoded.answers["repeat_contact"] == .noul(probability: 0.98))
        #expect(decoded.answers["Future_Answer"] == .other([
            "type": "future_kind",
            "Keep_Key": [true, 2, nil],
        ]))

        let reencoded = try HTTPClient.encoder.encode(decoded)
        let roundTripped = try HTTPClient.decoder.decode(SystemOneResponse.self, from: reencoded)
        #expect(roundTripped == decoded)
    }

    @Test func scoreAnswerAllowsOmittedLegendAndUsageAllowsTotalTokens() throws {
        let scoreWithoutLegend = SystemOneAnswer.score(
            score: 1.5,
            confidence: 0.75,
            probabilities: ["0": 0.25, "1": 0.5, "2": 0.25],
            legend: nil
        )
        try expectWire(
            scoreWithoutLegend,
            #"{"type":"score","score":1.5,"confidence":0.75,"probabilities":{"0":0.25,"1":0.5,"2":0.25}}"#
        )

        let usage = SystemOneUsage(inputTokens: 100, outputTokens: 5, totalTokens: 105)
        try expectWire(usage, #"{"input_tokens":100,"output_tokens":5,"total_tokens":105}"#)
    }

    @Test(arguments: [
        #"{"type":"noul"}"#,
        #"{"type":"noul","noul":"not-a-number"}"#,
        #"{"type":"choice","choice":"eng","confidence":0.9}"#,
        #"{"type":"score","score":1.0,"probabilities":{"0":1.0}}"#,
        #"{"missing_type":true}"#,
    ])
    func malformedKnownAnswersThrowDecodingErrors(fixture: String) {
        #expect(throws: DecodingError.self) {
            try HTTPClient.decoder.decode(SystemOneAnswer.self, from: Data(fixture.utf8))
        }
    }

    @Test(arguments: [
        ("", "/providers/microsoft/v1/systemone"),
        ("/", "/providers/microsoft/v1/systemone"),
        ("/openai/v1", "/providers/microsoft/v1/systemone"),
        ("/openai/v1/", "/providers/microsoft/v1/systemone"),
        ("/openai", "/providers/microsoft/v1/systemone"),
        ("/openai/", "/providers/microsoft/v1/systemone"),
        ("/models", "/providers/microsoft/v1/systemone"),
        ("/models/", "/providers/microsoft/v1/systemone"),
        ("/v1", "/providers/microsoft/v1/systemone"),
        ("/v1/", "/providers/microsoft/v1/systemone"),
        ("/api/projects/my-project", "/providers/microsoft/v1/systemone"),
        ("/api/projects/my-project/", "/providers/microsoft/v1/systemone"),
        ("/api/projects/my-project/openai", "/providers/microsoft/v1/systemone"),
        ("/api/projects/my-project/openai/", "/providers/microsoft/v1/systemone"),
        ("/api/projects/my-project/openai/v1", "/providers/microsoft/v1/systemone"),
        ("/api/projects/my-project/openai/v1/", "/providers/microsoft/v1/systemone"),
        ("/api/projects/my-project/models", "/providers/microsoft/v1/systemone"),
        ("/api/projects/my-project/v1", "/providers/microsoft/v1/systemone"),
        ("/providers/microsoft/v1/systemone", "/providers/microsoft/v1/systemone"),
        ("/providers/microsoft/v1/systemone/", "/providers/microsoft/v1/systemone"),
        ("/providers/microsoft/v1", "/providers/microsoft/v1/systemone"),
        ("/providers/microsoft/v1/", "/providers/microsoft/v1/systemone"),
        ("openai/v1", "/providers/microsoft/v1/systemone"),
        ("/custom", "/custom/providers/microsoft/v1/systemone"),
        ("/custom/prefix/", "/custom/prefix/providers/microsoft/v1/systemone"),
        ("custom/prefix", "/custom/prefix/providers/microsoft/v1/systemone"),
        ("/custom/v1", "/custom/v1/providers/microsoft/v1/systemone"),
        ("/custom/providers/microsoft/v1/systemone", "/custom/providers/microsoft/v1/systemone"),
        ("/custom/providers/microsoft/v1", "/custom/providers/microsoft/v1/systemone"),
        ("/api/projects", "/api/projects/providers/microsoft/v1/systemone"),
        ("/api/projects/my-project/other", "/api/projects/my-project/other/providers/microsoft/v1/systemone"),
    ])
    func resolvePathNormalizesFoundryRoutesAndPreservesCustomPaths(input: String, expected: String) {
        #expect(SystemOne.resolvePath(basePath: input) == expected)
    }
}
