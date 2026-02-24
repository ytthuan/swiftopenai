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

    @Test func apiErrorParsing403() async throws {
        let errorJson = """
        {"error": {"message": "Permission denied", "type": "insufficient_permissions", "param": null, "code": null}}
        """
        let client = makeMockClient(json: errorJson, statusCode: 403)

        do {
            _ = try await client.models.list()
            #expect(Bool(false), "Should have thrown")
        } catch let error as OpenAIError {
            if case .permissionDeniedError(let message) = error {
                #expect(message == "Permission denied")
            } else {
                #expect(Bool(false), "Wrong error type: \(error)")
            }
        }
    }

    @Test func apiErrorParsing404() async throws {
        let errorJson = """
        {"error": {"message": "Model not found", "type": "invalid_request_error", "param": null, "code": "model_not_found"}}
        """
        let client = makeMockClient(json: errorJson, statusCode: 404)

        do {
            _ = try await client.models.list()
            #expect(Bool(false), "Should have thrown")
        } catch let error as OpenAIError {
            if case .notFoundError(let message) = error {
                #expect(message == "Model not found")
            } else {
                #expect(Bool(false), "Wrong error type: \(error)")
            }
        }
    }

    @Test func apiErrorParsing422() async throws {
        let errorJson = """
        {"error": {"message": "Invalid parameter", "type": "invalid_request_error", "param": "model", "code": null}}
        """
        let client = makeMockClient(json: errorJson, statusCode: 422)

        do {
            _ = try await client.models.list()
            #expect(Bool(false), "Should have thrown")
        } catch let error as OpenAIError {
            if case .unprocessableEntityError(let message) = error {
                #expect(message == "Invalid parameter")
            } else {
                #expect(Bool(false), "Wrong error type: \(error)")
            }
        }
    }

    @Test func apiErrorParsing500() async throws {
        let errorJson = """
        {"error": {"message": "Internal server error", "type": "server_error", "param": null, "code": null}}
        """
        let client = makeMockClient(json: errorJson, statusCode: 500)

        do {
            _ = try await client.models.list()
            #expect(Bool(false), "Should have thrown")
        } catch let error as OpenAIError {
            if case .internalServerError(let message) = error {
                #expect(message == "Internal server error")
            } else {
                #expect(Bool(false), "Wrong error type: \(error)")
            }
        }
    }

    @Test func apiErrorParsingUnknownStatus() async throws {
        let errorJson = """
        {"error": {"message": "I'm a teapot", "type": "teapot_error", "param": null, "code": "teapot"}}
        """
        let client = makeMockClient(json: errorJson, statusCode: 418)

        do {
            _ = try await client.models.list()
            #expect(Bool(false), "Should have thrown")
        } catch let error as OpenAIError {
            if case .apiError(let statusCode, let message, let type, let code) = error {
                #expect(statusCode == 418)
                #expect(message == "I'm a teapot")
                #expect(type == "teapot_error")
                #expect(code == "teapot")
            } else {
                #expect(Bool(false), "Wrong error type: \(error)")
            }
        }
    }

    @Test func requestIncludesUserAgentHeader() async throws {
        let client = makeMockClient(json: "{\"object\": \"list\", \"data\": []}")
        _ = try await client.models.list()
        let request = MockURLProtocol.lastRequest
        #expect(request?.value(forHTTPHeaderField: "User-Agent") == "SwiftOpenAI/0.1.0")
    }

}
