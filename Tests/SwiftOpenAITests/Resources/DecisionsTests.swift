import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import SwiftOpenAI

extension MockAPITests {
    @Test func decisionsCreateOverloadsShareTheCompleteWireBody() async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let client = makeMockClient(json: DecisionsFixtures.response)
        defer { client.shutdown() }
        let request = DecisionCreateRequest(
            model: "gpt-6-luna",
            input: .items([.user(parts: [
                .text("Evidence", promptCacheBreakpoint: .init()),
                .json(["CustomerID": "Case_A", "nested_key": ["DoNotChange": true]]),
            ])]),
            questions: [.predicate(instructions: .text("Is damaged?"), name: "damaged")],
            promptCacheKey: "customer_A",
            promptCacheOptions: .init(mode: .explicit, ttl: .m30),
            safetyIdentifier: "user_opaque"
        )
        let result = try await client.decisions.create(request: request)
        #expect(result.answers.first == .predicate(name: "damaged", probability: 0.95))
        let firstBody = try #require(MockURLProtocol.lastRequestBody)
        let expected = """
        {
          "model":"gpt-6-luna",
          "input":[{"type":"message","role":"user","content":[
            {"type":"input_text","text":"Evidence","prompt_cache_breakpoint":{"mode":"explicit"}},
            {"type":"input_json","data":{"CustomerID":"Case_A","nested_key":{"DoNotChange":true}}}]}],
          "questions":[{"type":"predicate","instructions":"Is damaged?","name":"damaged"}],
          "prompt_cache_key":"customer_A","prompt_cache_options":{"mode":"explicit","ttl":"30m"},
          "safety_identifier":"user_opaque"
        }
        """
        #expect(try JSONDecoder().decode(JSONValue.self, from: firstBody)
                == JSONDecoder().decode(JSONValue.self, from: Data(expected.utf8)))
        _ = try await client.decisions.create(
            model: request.model,
            input: request.input,
            questions: request.questions,
            promptCacheKey: request.promptCacheKey,
            promptCacheOptions: request.promptCacheOptions,
            safetyIdentifier: request.safetyIdentifier
        )
        #expect(MockURLProtocol.lastRequestBody == firstBody)
        #expect(MockURLProtocol.requestCount == 2)
        let sent = try #require(MockURLProtocol.lastRequest)
        #expect(sent.httpMethod == "POST")
        #expect(sent.url?.path == "/v1/decisions")
        #expect(sent.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(sent.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
    }

    @Test(arguments: [false, true])
    func decisionsCreateOmitsUnsetOptionsForBothOverloads(useRequest: Bool) async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let client = makeMockClient(json: DecisionsFixtures.response)
        defer { client.shutdown() }
        let questions: [DecisionQuestion] = [.predicate(instructions: .text("Is damaged?"))]
        if useRequest {
            _ = try await client.decisions.create(request: .init(model: "future-model", input: .text("Evidence"), questions: questions))
        } else {
            _ = try await client.decisions.create(model: "future-model", input: .text("Evidence"), questions: questions)
        }
        let data = try #require(MockURLProtocol.lastRequestBody)
        let expected = #"{"model":"future-model","input":"Evidence","questions":[{"type":"predicate","instructions":"Is damaged?"}]}"#
        #expect(try JSONDecoder().decode(JSONValue.self, from: data)
                == JSONDecoder().decode(JSONValue.self, from: Data(expected.utf8)))
    }

    @Test(arguments: [false, true])
    func decisionsUsesConfiguredBaseURLQueryAndAuthentication(customHeader: Bool) async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let baseURL = try #require(URL(string: "https://proxy.example.test/openai/v1/"))
        MockURLProtocol.mockResponse = (
            Data(DecisionsFixtures.response.utf8),
            try #require(HTTPURLResponse(url: baseURL, statusCode: 200, httpVersion: nil, headerFields: nil))
        )
        let client = OpenAI(
            apiKey: "proxy-key",
            organization: "org_test",
            project: "proj_test",
            baseURL: baseURL,
            maxRetries: 0,
            defaultQueryItems: [.init(name: "api-version", value: "test-version")],
            apiKeyHeaderName: customHeader ? "api-key" : nil,
            session: session
        )
        defer { client.shutdown() }
        _ = try await client.decisions.create(
            model: "gpt-6-luna", input: .text("Evidence"),
            questions: [.predicate(instructions: .text("Relevant?"))]
        )
        let sent = try #require(MockURLProtocol.lastRequest)
        #expect(sent.url?.absoluteString == "https://proxy.example.test/openai/v1/decisions?api-version=test-version")
        #expect(sent.value(forHTTPHeaderField: "OpenAI-Organization") == "org_test")
        #expect(sent.value(forHTTPHeaderField: "OpenAI-Project") == "proj_test")
        if customHeader {
            #expect(sent.value(forHTTPHeaderField: "api-key") == "proxy-key")
            #expect(sent.value(forHTTPHeaderField: "Authorization") == nil)
        } else {
            #expect(sent.value(forHTTPHeaderField: "Authorization") == "Bearer proxy-key")
        }
    }

    @Test func decisionsPropagatesAPIErrorDetails() async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let client = makeMockClient(
            json: #"{"error":{"message":"Invalid questions","type":"invalid_request_error","code":"invalid_questions"}}"#,
            statusCode: 400
        )
        defer { client.shutdown() }
        await #expect(throws: OpenAIError.apiError(
            statusCode: 400, message: "Invalid questions", type: "invalid_request_error", code: "invalid_questions"
        )) {
            try await client.decisions.create(model: "gpt-6-luna", input: .text("Evidence"), questions: [])
        }
        #expect(MockURLProtocol.requestCount == 1)
    }

    @Test(arguments: [
        "not JSON",
        "{\"model\":\"gpt-6-luna\",\"answers\":[{\"type\":\"predicate\",\"name\":null}],\"usage\":\(DecisionsFixtures.usage)}",
    ])
    func decisionsWrapsMalformedResponsesAsSDKDecodingErrors(fixture: String) async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let client = makeMockClient(json: fixture)
        defer { client.shutdown() }
        do {
            _ = try await client.decisions.create(model: "gpt-6-luna", input: .text("Evidence"), questions: [
                .predicate(instructions: .text("Relevant?")),
            ])
            Issue.record("Expected a decoding error")
        } catch let error as OpenAIError {
            guard case .decodingError(let message) = error else {
                Issue.record("Expected decodingError, received \(error)")
                return
            }
            #expect(!message.isEmpty)
        }
    }

    @Test(arguments: [401, 403, 404, 409, 422, 429, 500, 503])
    func decisionsPropagatesTypedHTTPFailures(statusCode: Int) async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let client = makeMockClient(json: #"{"error":{"message":"Proxy rejected request"}}"#, statusCode: statusCode)
        defer { client.shutdown() }
        let expected: OpenAIError
        switch statusCode {
        case 401: expected = .authenticationError(message: "Proxy rejected request")
        case 403: expected = .permissionDeniedError(message: "Proxy rejected request")
        case 404: expected = .notFoundError(message: "Proxy rejected request")
        case 409: expected = .conflictError(message: "Proxy rejected request")
        case 422: expected = .unprocessableEntityError(message: "Proxy rejected request")
        case 429: expected = .rateLimitError(message: "Proxy rejected request")
        default: expected = .internalServerError(message: "Proxy rejected request")
        }
        await #expect(throws: expected) {
            try await client.decisions.create(
                model: "gpt-6-luna", input: .text("Evidence"),
                questions: [.predicate(instructions: .text("Relevant?"))]
            )
        }
        #expect(MockURLProtocol.requestCount == 1)
    }

    @Test(arguments: [429, 503])
    func decisionsRetriesTransientFailuresThroughTheSharedTransport(statusCode: Int) async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let url = try #require(URL(string: "https://proxy.example.test/v1/decisions"))
        MockURLProtocol.mockResponses = [
            (Data(#"{"error":{"message":"Try again"}}"#.utf8),
             try #require(HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: ["Retry-After": "0"]))),
            (Data(DecisionsFixtures.response.utf8),
             try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))),
        ]
        let client = makeMockClientWithRetry(maxRetries: 1, retryDelay: 0)
        defer { client.shutdown() }
        let result = try await client.decisions.create(
            model: "gpt-6-luna", input: .text("Evidence"),
            questions: [.predicate(instructions: .text("Relevant?"))]
        )
        #expect(MockURLProtocol.requestCount == 2)
        #expect(result.model == "gpt-6-luna")
        #expect(result.answers.first == .predicate(name: "damaged", probability: 0.95))
        #expect(MockURLProtocol.lastRequest?.url?.path == "/v1/decisions")
    }
}
