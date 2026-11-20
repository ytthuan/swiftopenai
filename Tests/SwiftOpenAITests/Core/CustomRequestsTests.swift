import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import SwiftOpenAI

enum CustomRequestMethod: String, CaseIterable, Sendable {
    case get = "GET", post = "POST", put = "PUT", patch = "PATCH", delete = "DELETE"
}

private func sendCustomJSON(
    _ method: CustomRequestMethod,
    client: OpenAI,
    path: String,
    body: JSONValue? = nil,
    queryItems: [URLQueryItem]? = nil
) async throws -> JSONValue {
    switch method {
    case .get: return try await client.get(path, queryItems: queryItems)
    case .post: return try await client.post(path, body: body, queryItems: queryItems)
    case .put: return try await client.put(path, body: body, queryItems: queryItems)
    case .patch: return try await client.patch(path, body: body, queryItems: queryItems)
    case .delete: return try await client.delete(path, body: body, queryItems: queryItems)
    }
}

private actor CustomRequestTokenProvider: TokenProvider {
    private(set) var calls = 0

    func getToken() async throws -> String {
        calls += 1
        return "token-\(calls)"
    }
}

private enum CustomRequestFixtures {
    static let response = #"{"Unchanged_Key":{"Team_A":["second","first"],"null_field":null},"input_tokens":120}"#
    static let systemOneResponse = """
    {
      "model":"microsoft-decision-1",
      "answers":{
        "team":{"type":"choice","choice":"engineering","confidence":0.99,
          "probabilities":{"billing":0.005,"engineering":0.99,"support":0.005}},
        "severity":{"type":"score","score":2.9,"confidence":0.9,
          "probabilities":{"0":0,"1":0,"2":0.1,"3":0.9},
          "legend":{"0":"Cosmetic","1":"Minor","2":"Major","3":"Critical"}},
        "repeat_contact":{"type":"noul","noul":0.98}
      },
      "usage":{"input_tokens":120,"output_tokens":3},
      "Future_Field":{"Keep_This_Key":true}
    }
    """

    static let questions: JSONValue = [
        "team": [
            "type": "choice", "instructions": "Which team should handle this ticket?",
            "criteria": ["billing": "Charges", "engineering": "Bugs", "support": "How-to"],
        ],
        "severity": [
            "type": "score", "instructions": "How severe?",
            "criteria": ["Cosmetic", "Minor", "Major", "Critical"],
        ],
        "repeat_contact": ["type": "noul", "instructions": "Has the customer contacted us before?"],
    ]
}

extension MockAPITests {
    @Test(arguments: CustomRequestMethod.allCases, [false, true])
    func customRequestsUseCorrectVerbBasePathQueryAndBody(method: CustomRequestMethod, leadingSlash: Bool) async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let baseURL = try #require(URL(string: "https://proxy.example.test/openai/v1/"))
        MockURLProtocol.mockResponse = (
            Data(CustomRequestFixtures.response.utf8),
            try #require(HTTPURLResponse(url: baseURL, statusCode: 200, httpVersion: nil, headerFields: nil))
        )
        let client = OpenAI(
            apiKey: "custom-key", organization: "org_custom", project: "proj_custom",
            baseURL: baseURL, maxRetries: 0,
            defaultQueryItems: [.init(name: "api-version", value: "test"), .init(name: "tag", value: "default")],
            session: session
        )
        defer { client.shutdown() }
        let body: JSONValue = ["State_ID": "case-A", "nested_key": ["DoNotChange": [true, "false", nil]]]
        let response = try await sendCustomJSON(
            method, client: client, path: leadingSlash ? "/custom/items" : "custom/items", body: body,
            queryItems: [.init(name: "tag", value: "request & value"), .init(name: "flag", value: nil)]
        )
        #expect(response == (try JSONDecoder().decode(JSONValue.self, from: Data(CustomRequestFixtures.response.utf8))))
        let sent = try #require(MockURLProtocol.lastRequest)
        #expect(sent.httpMethod == method.rawValue)
        #expect(sent.url?.path == "/openai/v1/custom/items")
        let components = try #require(sent.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) })
        #expect(components.queryItems == [
            .init(name: "api-version", value: "test"), .init(name: "tag", value: "default"),
            .init(name: "tag", value: "request & value"), .init(name: "flag", value: nil),
        ])
        #expect(sent.value(forHTTPHeaderField: "Authorization") == "Bearer custom-key")
        #expect(sent.value(forHTTPHeaderField: "OpenAI-Organization") == "org_custom")
        #expect(sent.value(forHTTPHeaderField: "OpenAI-Project") == "proj_custom")
        #expect(sent.value(forHTTPHeaderField: "User-Agent") == SDK.userAgent)
        if method == .get {
            #expect(MockURLProtocol.lastRequestBody == nil)
            #expect(sent.value(forHTTPHeaderField: "Content-Type") == nil)
        } else {
            #expect(sent.value(forHTTPHeaderField: "Content-Type") == "application/json")
            let data = try #require(MockURLProtocol.lastRequestBody)
            #expect(try JSONDecoder().decode(JSONValue.self, from: data) == body)
        }
    }

    @Test(arguments: CustomRequestMethod.allCases)
    func customRequestsOmitUnsetBodyAndQuery(method: CustomRequestMethod) async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let client = makeMockClient(json: "null")
        defer { client.shutdown() }
        let result = try await sendCustomJSON(method, client: client, path: "custom")
        #expect(result == .null)
        #expect(MockURLProtocol.lastRequestBody == nil)
        #expect(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Content-Type") == nil)
        #expect(MockURLProtocol.lastRequest?.url?.query == nil)
    }

    @Test(arguments: ["", "/", "folder name/action:run/"])
    func customRequestsSupportBaseRootAndUnescapedPaths(path: String) async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let client = makeMockClient(json: "true")
        defer { client.shutdown() }
        let result: Bool = try await client.get(path)
        #expect(result)
        let components = MockURLProtocol.lastRequest?.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        #expect(components?.path == (path == "/" ? "/v1/" : "/v1/" + path))
        if path.contains(" ") {
            #expect(MockURLProtocol.lastRequest?.url?.absoluteString.contains("folder%20name") == true)
        }
    }

    @Test(arguments: [
        "https://other.example.test/steal", "http:other", "//other.example.test/path",
        "///other", "custom\\path", "custom?api-version=1", "custom#fragment",
        ".", "..", "./items", "../items", "items/..", "items/./next",
        "items/%2e%2e/next", "items/%252e%252e/next", "items/%2fnext", "items/\nnext", "items/\u{0}next",
    ])
    func customRequestsRejectInvalidPathsBeforeSending(path: String) async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let client = makeMockClient(json: "{}")
        defer { client.shutdown() }
        do {
            let _: JSONValue = try await client.post(path)
            Issue.record("Expected an invalid-path error")
        } catch let error as OpenAIError {
            guard case .apiError(let status, let message, _, _) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(status == 0)
            #expect(message.contains("relative"))
        }
        #expect(MockURLProtocol.requestCount == 0)
    }

    @Test func customRequestsEncodeTypedBodiesAndDecodeTypedResponses() async throws {
        struct Body: Encodable, Sendable {
            let deploymentName: String
            let state: JSONValue
            let omittedValue: String? = nil
        }
        struct Response: Decodable, Sendable {
            let returnedModel: String
            let inputTokens: Int
        }
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let client = makeMockClient(json: #"{"returned_model":"microsoft-decision-1","input_tokens":120}"#)
        defer { client.shutdown() }
        let response: Response = try await client.post("custom", body: Body(
            deploymentName: "Decision-1", state: ["Keep_This_Key": "unchanged"]
        ))
        #expect(response.returnedModel == "microsoft-decision-1")
        #expect(response.inputTokens == 120)
        let body = try #require(MockURLProtocol.lastRequestBody)
        #expect(try JSONDecoder().decode(JSONValue.self, from: body) == [
            "deployment_name": "Decision-1", "state": ["Keep_This_Key": "unchanged"],
        ])
    }

    @Test func customRequestsDistinguishAnExplicitNullBodyFromNoBody() async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let client = makeMockClient(json: "null")
        defer { client.shutdown() }
        let _: JSONValue = try await client.post("custom", body: JSONValue.null)
        #expect(MockURLProtocol.lastRequestBody == Data("null".utf8))
        #expect(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test(arguments: [false, true])
    func customRequestsSupportNativeMicrosoftDecisionWireFormat(structuredState: Bool) async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let baseURL = try #require(URL(string: "https://foundry.example.test"))
        MockURLProtocol.mockResponse = (
            Data(CustomRequestFixtures.systemOneResponse.utf8),
            try #require(HTTPURLResponse(url: baseURL, statusCode: 200, httpVersion: nil, headerFields: nil))
        )
        let client = OpenAI(apiKey: "azure-key", baseURL: baseURL, maxRetries: 0, apiKeyHeaderName: "api-key", session: session)
        defer { client.shutdown() }
        let state: JSONValue = structuredState
            ? ["Customer_ID": "Case_A", "contact_count": 3, "events": ["first", "second"]]
            : "The API returns 500 on every call. This is my third report."
        let body: JSONValue = ["model": "Decision-1", "state": state, "questions": CustomRequestFixtures.questions]
        let response: JSONValue = try await client.post("/providers/microsoft/v1/systemone", body: body)
        #expect(response == (try JSONDecoder().decode(JSONValue.self, from: Data(CustomRequestFixtures.systemOneResponse.utf8))))
        let sent = try #require(MockURLProtocol.lastRequest)
        #expect(sent.url?.absoluteString == "https://foundry.example.test/providers/microsoft/v1/systemone")
        #expect(sent.httpMethod == "POST")
        #expect(sent.value(forHTTPHeaderField: "api-key") == "azure-key")
        #expect(sent.value(forHTTPHeaderField: "Authorization") == nil)
        let encoded = try #require(MockURLProtocol.lastRequestBody)
        #expect(try JSONDecoder().decode(JSONValue.self, from: encoded) == body)
    }

    @Test(arguments: [429, 503])
    func customRequestsRetryAndRefreshTokenProvider(statusCode: Int) async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let url = try #require(URL(string: "https://foundry.example.test/providers/microsoft/v1/systemone"))
        MockURLProtocol.mockResponses = [
            (Data(#"{"error":{"message":"Try again"}}"#.utf8),
             try #require(HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: ["Retry-After": "0"]))),
            (Data(CustomRequestFixtures.systemOneResponse.utf8),
             try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))),
        ]
        let provider = CustomRequestTokenProvider()
        let client = OpenAI(
            apiKey: "unused", baseURL: try #require(URL(string: "https://foundry.example.test/")),
            maxRetries: 1, retryDelay: 0, tokenProvider: provider, session: session
        )
        defer { client.shutdown() }
        let body: JSONValue = ["model": "Decision-1", "state": "Evidence", "questions": CustomRequestFixtures.questions]
        let result: JSONValue = try await client.post("/providers/microsoft/v1/systemone", body: body)
        #expect(result == (try JSONDecoder().decode(JSONValue.self, from: Data(CustomRequestFixtures.systemOneResponse.utf8))))
        #expect(MockURLProtocol.requestCount == 2)
        #expect(await provider.calls == 2)
        #expect(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer token-2")
        #expect(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "api-key") == nil)
        #expect(try JSONDecoder().decode(JSONValue.self, from: #require(MockURLProtocol.lastRequestBody)) == body)
    }

    @Test func customRequestsPropagateDetailedAPIErrors() async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let client = makeMockClient(
            json: #"{"error":{"message":"Invalid state","type":"invalid_request_error","code":"invalid_state"}}"#,
            statusCode: 400
        )
        defer { client.shutdown() }
        await #expect(throws: OpenAIError.apiError(
            statusCode: 400, message: "Invalid state", type: "invalid_request_error", code: "invalid_state"
        )) {
            let _: JSONValue = try await client.post("providers/microsoft/v1/systemone")
        }
        #expect(MockURLProtocol.requestCount == 1)
    }

    @Test(arguments: [401, 429, 503])
    func customRequestsPreserveTypedHTTPFailures(statusCode: Int) async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let client = makeMockClient(json: #"{"error":{"message":"Rejected"}}"#, statusCode: statusCode)
        defer { client.shutdown() }
        let expected: OpenAIError = switch statusCode {
        case 401: .authenticationError(message: "Rejected")
        case 429: .rateLimitError(message: "Rejected")
        default: .internalServerError(message: "Rejected")
        }
        await #expect(throws: expected) {
            let _: JSONValue = try await client.post("custom")
        }
        #expect(MockURLProtocol.requestCount == 1)
    }

    @Test(arguments: ["not JSON", "", #"{"input_tokens":"wrong type"}"#])
    func customRequestsWrapInvalidJSONAndTypedResponseFailures(response: String) async throws {
        struct Response: Decodable, Sendable { let inputTokens: Int }
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let client = makeMockClient(json: response)
        defer { client.shutdown() }
        do {
            let _: Response = try await client.post("custom")
            Issue.record("Expected decodingError")
        } catch let error as OpenAIError {
            guard case .decodingError(let message) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(!message.isEmpty)
        }
    }

    @Test func customRequestsPropagateBodyEncodingFailuresBeforeSending() async throws {
        enum EncodingFailure: Error { case expected }
        struct InvalidBody: Encodable, Sendable {
            func encode(to encoder: Encoder) throws { throw EncodingFailure.expected }
        }
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let client = makeMockClient(json: "{}")
        defer { client.shutdown() }
        await #expect(throws: EncodingFailure.expected) {
            let _: JSONValue = try await client.post("custom", body: InvalidBody())
        }
        #expect(MockURLProtocol.requestCount == 0)
    }
}
