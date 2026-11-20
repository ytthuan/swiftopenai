import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import SwiftOpenAI

private actor SystemOneTokenProvider: TokenProvider {
    private(set) var calls = 0

    func getToken() async throws -> String {
        calls += 1
        return "entra-token-\(calls)"
    }
}

extension MockAPITests {
    @Test func systemOneCreateOverloadsShareTheCompleteWireBody() async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let baseURL = try #require(URL(string: "https://myrg.services.ai.azure.com"))
        MockURLProtocol.mockResponse = (
            Data(SystemOneFixtures.response.utf8),
            try #require(HTTPURLResponse(url: baseURL, statusCode: 200, httpVersion: nil, headerFields: nil))
        )
        let client = OpenAI(
            apiKey: "azure-key",
            baseURL: baseURL,
            maxRetries: 0,
            apiKeyHeaderName: "api-key",
            session: session
        )
        defer { client.shutdown() }

        let request = SystemOneCreateRequest(
            model: "Decision-1.1",
            state: .json(["message": "Payment integration fails.", "contact_count": 3]),
            questions: [
                "team": .choice(
                    instructions: "Which team should handle this ticket?",
                    criteria: ["billing": "Charges", "engineering": "Bugs", "support_team": "How-to"]
                ),
                "severity": .score(
                    instructions: "How severe is this incident?",
                    criteria: ["Cosmetic", "Minor", "Major", "Critical"]
                ),
                "repeat_contact": .noul(
                    instructions: "Has the customer contacted support before?",
                    criteria: .init(true: "Prior contact mentioned", false: "First contact")
                ),
            ],
            assets: ["photo.png": .image(format: "png", dataBase64: "AQID")]
        )

        let first = try await client.systemOne.create(request: request)
        #expect(first.model == "microsoft-decision-1.1")
        #expect(first.answers["repeat_contact"] == .noul(probability: 0.98))
        #expect(first.answers["team"] == .choice(
            choice: "engineering",
            confidence: 0.99,
            probabilities: ["billing": 0.005, "engineering": 0.99, "support_team": 0.005]
        ))
        #expect(first.usage == SystemOneUsage(inputTokens: 120, outputTokens: 3))

        let firstBody = try #require(MockURLProtocol.lastRequestBody)
        let expected = """
        {
          "model":"Decision-1.1",
          "state":{"message":"Payment integration fails.","contact_count":3},
          "questions":{
            "team":{"type":"choice","instructions":"Which team should handle this ticket?",
              "criteria":{"billing":"Charges","engineering":"Bugs","support_team":"How-to"}},
            "severity":{"type":"score","instructions":"How severe is this incident?",
              "criteria":["Cosmetic","Minor","Major","Critical"]},
            "repeat_contact":{"type":"noul","instructions":"Has the customer contacted support before?",
              "criteria":{"true":"Prior contact mentioned","false":"First contact"}}
          },
          "assets":{"photo.png":{"type":"image","format":"png","data_base64":"AQID"}}
        }
        """
        #expect(try JSONDecoder().decode(JSONValue.self, from: firstBody)
                == JSONDecoder().decode(JSONValue.self, from: Data(expected.utf8)))

        let second = try await client.systemOne.create(
            model: request.model,
            state: request.state,
            questions: request.questions,
            assets: request.assets
        )
        #expect(second == first)
        #expect(MockURLProtocol.lastRequestBody == firstBody)
        #expect(MockURLProtocol.requestCount == 2)

        let sent = try #require(MockURLProtocol.lastRequest)
        #expect(sent.httpMethod == "POST")
        #expect(sent.url?.absoluteString == "https://myrg.services.ai.azure.com/providers/microsoft/v1/systemone")
        #expect(sent.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(sent.value(forHTTPHeaderField: "api-key") == "azure-key")
        #expect(sent.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test(arguments: [
        "https://myrg.services.ai.azure.com",
        "https://myrg.services.ai.azure.com/",
        "https://myrg.services.ai.azure.com/openai/v1",
        "https://myrg.services.ai.azure.com/openai/v1/",
        "https://myrg.services.ai.azure.com/openai",
        "https://myrg.services.ai.azure.com/models",
        "https://myrg.services.ai.azure.com/v1",
        "https://myrg.services.ai.azure.com/api/projects/my-project",
        "https://myrg.services.ai.azure.com/api/projects/my-project/openai",
        "https://myrg.services.ai.azure.com/api/projects/my-project/openai/v1",
        "https://myrg.services.ai.azure.com/api/projects/my-project/openai/v1/",
        "https://myrg.services.ai.azure.com/api/projects/my-project/models",
        "https://myrg.services.ai.azure.com/providers/microsoft/v1/systemone",
    ])
    func systemOneNormalizesFoundryBaseURLs(baseURLString: String) async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let baseURL = try #require(URL(string: baseURLString))
        MockURLProtocol.mockResponse = (
            Data(SystemOneFixtures.response.utf8),
            try #require(HTTPURLResponse(url: baseURL, statusCode: 200, httpVersion: nil, headerFields: nil))
        )
        let client = OpenAI(apiKey: "azure-key", baseURL: baseURL, maxRetries: 0, apiKeyHeaderName: "api-key", session: session)
        defer { client.shutdown() }

        _ = try await client.systemOne.create(
            model: "Decision-1.1",
            state: .text("The payment integration still fails."),
            questions: ["urgent": .noul(instructions: "Does this message convey urgency?")]
        )

        let sent = try #require(MockURLProtocol.lastRequest)
        #expect(sent.url?.absoluteString == "https://myrg.services.ai.azure.com/providers/microsoft/v1/systemone")
    }

    @Test(arguments: [
        ("https://proxy.example.test/custom", "https://proxy.example.test/custom/providers/microsoft/v1/systemone"),
        ("https://proxy.example.test/custom/prefix/", "https://proxy.example.test/custom/prefix/providers/microsoft/v1/systemone"),
        ("https://proxy.example.test/custom/v1", "https://proxy.example.test/custom/v1/providers/microsoft/v1/systemone"),
        ("https://proxy.example.test/api/projects/p1/custom", "https://proxy.example.test/api/projects/p1/custom/providers/microsoft/v1/systemone"),
    ])
    func systemOnePreservesCustomNonFoundryBasePaths(baseURLString: String, expectedURL: String) async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let baseURL = try #require(URL(string: baseURLString))
        MockURLProtocol.mockResponse = (
            Data(SystemOneFixtures.response.utf8),
            try #require(HTTPURLResponse(url: baseURL, statusCode: 200, httpVersion: nil, headerFields: nil))
        )
        let client = OpenAI(apiKey: "proxy-key", baseURL: baseURL, maxRetries: 0, session: session)
        defer { client.shutdown() }

        _ = try await client.systemOne.create(
            model: "Decision-1.1",
            state: .text("Evidence"),
            questions: ["urgent": .noul(instructions: "Urgent?")]
        )

        let sent = try #require(MockURLProtocol.lastRequest)
        #expect(sent.url?.absoluteString == expectedURL)
    }

    @Test func systemOneWorksWithAzureAndAzureFoundryInitializers() async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let responseURL = try #require(URL(string: "https://myrg.services.ai.azure.com/providers/microsoft/v1/systemone"))
        MockURLProtocol.mockResponse = (
            Data(SystemOneFixtures.response.utf8),
            try #require(HTTPURLResponse(url: responseURL, statusCode: 200, httpVersion: nil, headerFields: nil))
        )

        let azureClient = OpenAI.azure(
            resourceName: "myrg",
            apiKey: "azure-key",
            endpointSuffix: "services.ai.azure.com",
            maxRetries: 0,
            session: session
        )
        defer { azureClient.shutdown() }
        _ = try await azureClient.systemOne.create(
            model: "Decision-1.1",
            state: .text("Evidence"),
            questions: ["urgent": .noul(instructions: "Urgent?")]
        )
        let azureRequest = try #require(MockURLProtocol.lastRequest)
        #expect(azureRequest.url?.absoluteString == "https://myrg.services.ai.azure.com/providers/microsoft/v1/systemone")
        #expect(azureRequest.value(forHTTPHeaderField: "api-key") == "azure-key")
        #expect(azureRequest.value(forHTTPHeaderField: "Authorization") == nil)

        let foundryClient = OpenAI.azureFoundry(
            endpoint: "https://myrg.services.ai.azure.com/api/projects/myproject",
            token: "entra-token",
            maxRetries: 0,
            session: session
        )
        defer { foundryClient.shutdown() }
        _ = try await foundryClient.systemOne.create(
            model: "Decision-1.1",
            state: .text("Evidence"),
            questions: ["urgent": .noul(instructions: "Urgent?")]
        )
        let foundryRequest = try #require(MockURLProtocol.lastRequest)
        #expect(foundryRequest.url?.absoluteString == "https://myrg.services.ai.azure.com/providers/microsoft/v1/systemone?api-version=2025-11-15-preview")
        #expect(foundryRequest.value(forHTTPHeaderField: "Authorization") == "Bearer entra-token")
    }

    @Test func azureSystemOneUsesCognitiveServicesAudienceAndNativeRoute() async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let tokenURL = try #require(URL(string: "https://login.microsoftonline.com/tenant-123/oauth2/v2.0/token"))
        let systemOneURL = try #require(URL(string: "https://myrg.services.ai.azure.com/providers/microsoft/v1/systemone"))
        MockURLProtocol.mockResponses = [
            (
                Data(#"{"access_token":"entra-token","expires_in":3600,"token_type":"Bearer"}"#.utf8),
                try #require(HTTPURLResponse(url: tokenURL, statusCode: 200, httpVersion: nil, headerFields: nil))
            ),
            (
                Data(SystemOneFixtures.response.utf8),
                try #require(HTTPURLResponse(url: systemOneURL, statusCode: 200, httpVersion: nil, headerFields: nil))
            ),
        ]
        let client = OpenAI.azureSystemOne(
            resourceName: "myrg",
            tenantId: "tenant-123",
            clientId: "client-456",
            clientSecret: "secret-789",
            maxRetries: 0,
            session: session
        )
        defer { client.shutdown() }

        _ = try await client.systemOne.create(
            model: "Decision-1.1",
            state: .text("Evidence"),
            questions: ["urgent": .noul(instructions: "Is this urgent?")]
        )

        #expect(MockURLProtocol.requestCount == 2)
        let tokenRequest = try #require(MockURLProtocol.recordedRequests.first)
        #expect(tokenRequest.url == tokenURL)
        let tokenBody = try #require(MockURLProtocol.recordedRequestBodies.first ?? nil)
        #expect(String(decoding: tokenBody, as: UTF8.self)
            .contains("scope=https%3A%2F%2Fcognitiveservices.azure.com%2F.default"))

        let systemOneRequest = try #require(MockURLProtocol.recordedRequests.dropFirst().first)
        #expect(systemOneRequest.url == systemOneURL)
        #expect(systemOneRequest.value(forHTTPHeaderField: "Authorization") == "Bearer entra-token")
    }

    @Test func explicitProviderRoutingSeparatesDecisionsSystemOneAndCustomRequests() async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let baseURL = try #require(URL(string: "https://myrg.services.ai.azure.com/openai/v1"))
        MockURLProtocol.mockResponses = [
            (Data(DecisionsFixtures.response.utf8),
             try #require(HTTPURLResponse(url: baseURL, statusCode: 200, httpVersion: nil, headerFields: nil))),
            (Data(SystemOneFixtures.response.utf8),
             try #require(HTTPURLResponse(url: baseURL, statusCode: 200, httpVersion: nil, headerFields: nil))),
            (Data(#"{"ok":true}"#.utf8),
             try #require(HTTPURLResponse(url: baseURL, statusCode: 200, httpVersion: nil, headerFields: nil))),
        ]
        let client = OpenAI(apiKey: "azure-key", baseURL: baseURL, maxRetries: 0, apiKeyHeaderName: "api-key", session: session)
        defer { client.shutdown() }

        _ = try await client.decisions.create(
            model: "gpt-6-luna",
            input: .text("Evidence"),
            questions: [.predicate(instructions: .text("Damaged?"), name: "damaged")]
        )
        #expect(MockURLProtocol.lastRequest?.url?.absoluteString == "https://myrg.services.ai.azure.com/openai/v1/decisions")

        _ = try await client.systemOne.create(
            model: "Decision-1.1",
            state: .text("Evidence"),
            questions: ["urgent": .noul(instructions: "Urgent?")]
        )
        #expect(MockURLProtocol.lastRequest?.url?.absoluteString == "https://myrg.services.ai.azure.com/providers/microsoft/v1/systemone")

        let custom: JSONValue = try await client.post("custom/items", body: JSONValue.object(["k": "v"]))
        #expect(custom == ["ok": true])
        #expect(MockURLProtocol.lastRequest?.url?.absoluteString == "https://myrg.services.ai.azure.com/openai/v1/custom/items")
    }

    @Test(arguments: [429, 503])
    func systemOneRetriesTransientFailuresAndRefreshesTokenProvider(statusCode: Int) async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let url = try #require(URL(string: "https://myrg.services.ai.azure.com/providers/microsoft/v1/systemone"))
        MockURLProtocol.mockResponses = [
            (Data(#"{"error":{"message":"Try again"}}"#.utf8),
             try #require(HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: ["Retry-After": "0"]))),
            (Data(SystemOneFixtures.response.utf8),
             try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))),
        ]
        let provider = SystemOneTokenProvider()
        let client = OpenAI(
            apiKey: "",
            baseURL: try #require(URL(string: "https://myrg.services.ai.azure.com/openai/v1")),
            maxRetries: 1,
            retryDelay: 0,
            tokenProvider: provider,
            session: session
        )
        defer { client.shutdown() }

        let result = try await client.systemOne.create(
            model: "Decision-1.1",
            state: .text("Evidence"),
            questions: ["repeat_contact": .noul(instructions: "Repeat?")]
        )
        #expect(MockURLProtocol.requestCount == 2)
        #expect(await provider.calls == 2)
        #expect(result.answers["repeat_contact"] == .noul(probability: 0.98))
        #expect(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer entra-token-2")
        #expect(MockURLProtocol.lastRequest?.url?.path == "/providers/microsoft/v1/systemone")
    }

    @Test func systemOnePropagatesAPIErrorDetails() async throws {
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
            try await client.systemOne.create(model: "Decision-1.1", state: .text("Evidence"), questions: [:])
        }
        #expect(MockURLProtocol.requestCount == 1)
    }

    @Test(arguments: [401, 403, 404, 422, 429, 500, 503])
    func systemOnePropagatesTypedHTTPFailures(statusCode: Int) async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let client = makeMockClient(json: #"{"error":{"message":"Rejected"}}"#, statusCode: statusCode)
        defer { client.shutdown() }
        let expected: OpenAIError = switch statusCode {
        case 401: .authenticationError(message: "Rejected")
        case 403: .permissionDeniedError(message: "Rejected")
        case 404: .notFoundError(message: "Rejected")
        case 422: .unprocessableEntityError(message: "Rejected")
        case 429: .rateLimitError(message: "Rejected")
        default: .internalServerError(message: "Rejected")
        }
        await #expect(throws: expected) {
            try await client.systemOne.create(
                model: "Decision-1.1",
                state: .text("Evidence"),
                questions: ["urgent": .noul(instructions: "Urgent?")]
            )
        }
        #expect(MockURLProtocol.requestCount == 1)
    }

    @Test(arguments: [
        "not JSON",
        #"{"model":"microsoft-decision-1.1","answers":{"urgent":{"type":"noul"}},"usage":{"input_tokens":10,"output_tokens":1}}"#,
    ])
    func systemOneWrapsMalformedResponsesAsDecodingErrors(fixture: String) async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let client = makeMockClient(json: fixture)
        defer { client.shutdown() }
        do {
            _ = try await client.systemOne.create(
                model: "Decision-1.1",
                state: .text("Evidence"),
                questions: ["urgent": .noul(instructions: "Urgent?")]
            )
            Issue.record("Expected decodingError")
        } catch let error as OpenAIError {
            guard case .decodingError(let message) = error else {
                Issue.record("Expected decodingError, received \(error)")
                return
            }
            #expect(!message.isEmpty)
        }
    }
}
