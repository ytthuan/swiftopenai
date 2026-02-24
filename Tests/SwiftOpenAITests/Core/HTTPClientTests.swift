import Testing
import Foundation
@testable import SwiftOpenAI

extension MockAPITests {

    @Test func requestIncludesAuthorizationHeader() async throws {
        let client = makeMockClient(json: "{\"object\": \"list\", \"data\": []}")
        _ = try await client.models.list()
        let request = MockURLProtocol.lastRequest
        #expect(request?.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
    }

    @Test func requestIncludesOrganizationHeader() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        MockURLProtocol.mockResponse = (
            "{\"object\": \"list\", \"data\": []}".data(using: .utf8)!,
            HTTPURLResponse(url: URL(string: "https://api.openai.com/v1")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )

        let client = OpenAI(apiKey: "test-key", organization: "org-123", session: session)
        _ = try await client.models.list()
        let request = MockURLProtocol.lastRequest
        #expect(request?.value(forHTTPHeaderField: "OpenAI-Organization") == "org-123")
    }

    @Test func apiErrorParsing401() async throws {
        let errorJson = """
        {"error": {"message": "Invalid API key", "type": "invalid_request_error", "param": null, "code": "invalid_api_key"}}
        """
        let client = makeMockClient(json: errorJson, statusCode: 401)

        do {
            _ = try await client.models.list()
            #expect(Bool(false), "Should have thrown")
        } catch let error as OpenAIError {
            if case .authenticationError(let message) = error {
                #expect(message == "Invalid API key")
            } else {
                #expect(Bool(false), "Wrong error type: \(error)")
            }
        }
    }

    @Test func apiErrorParsing429() async throws {
        let errorJson = """
        {"error": {"message": "Rate limit exceeded", "type": "rate_limit_error", "param": null, "code": null}}
        """
        let client = makeMockClient(json: errorJson, statusCode: 429)

        do {
            _ = try await client.models.list()
            #expect(Bool(false), "Should have thrown")
        } catch let error as OpenAIError {
            if case .rateLimitError(let message) = error {
                #expect(message == "Rate limit exceeded")
            } else {
                #expect(Bool(false), "Wrong error type: \(error)")
            }
        }
    }

}
