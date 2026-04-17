import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
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
            if case .apiError(let statusCode, let message, _, _) = error {
                #expect(statusCode == 418)
                #expect(message == "I'm a teapot")
            } else {
                #expect(Bool(false), "Wrong error type: \(error)")
            }
        }
    }

    @Test func requestIncludesUserAgentHeader() async throws {
        let client = makeMockClient(json: "{\"object\": \"list\", \"data\": []}")
        _ = try await client.models.list()
        let request = MockURLProtocol.lastRequest
        #expect(request?.value(forHTTPHeaderField: "User-Agent") == SDK.userAgent)
    }

    @Test func organizationHeaderStripsInjectedCRLF() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        MockURLProtocol.mockResponse = (
            "{\"object\": \"list\", \"data\": []}".data(using: .utf8)!,
            HTTPURLResponse(url: URL(string: "https://api.openai.com/v1")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )

        let client = OpenAI(apiKey: "test-key", organization: "org-123\r\nEvil-Header: injected", session: session)
        _ = try await client.models.list()
        let request = MockURLProtocol.lastRequest
        #expect(request?.value(forHTTPHeaderField: "OpenAI-Organization") == "org-123Evil-Header: injected")
    }

    @Test func projectHeaderStripsInjectedCRLF() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        MockURLProtocol.mockResponse = (
            "{\"object\": \"list\", \"data\": []}".data(using: .utf8)!,
            HTTPURLResponse(url: URL(string: "https://api.openai.com/v1")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )

        let client = OpenAI(apiKey: "test-key", project: "proj-456\r\nX-Bad: evil", session: session)
        _ = try await client.models.list()
        let request = MockURLProtocol.lastRequest
        #expect(request?.value(forHTTPHeaderField: "OpenAI-Project") == "proj-456X-Bad: evil")
    }

    // MARK: - Retry Tests

    @Test func retryOn429ThenSuccess() async throws {
        let errorJson = """
        {"error": {"message": "Rate limit exceeded", "type": "rate_limit_error", "param": null, "code": null}}
        """
        let successJson = """
        {"object": "list", "data": []}
        """

        MockURLProtocol.reset()
        MockURLProtocol.mockResponses = [
            (errorJson.data(using: .utf8)!, HTTPURLResponse(url: URL(string: "https://api.openai.com/v1")!, statusCode: 429, httpVersion: nil, headerFields: nil)!),
            (successJson.data(using: .utf8)!, HTTPURLResponse(url: URL(string: "https://api.openai.com/v1")!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        ]

        let client = makeMockClientWithRetry(maxRetries: 2)
        _ = try await client.models.list()
        #expect(MockURLProtocol.requestCount == 2)
    }

    @Test func retryOn500ThenSuccess() async throws {
        let errorJson = """
        {"error": {"message": "Internal server error", "type": "server_error", "param": null, "code": null}}
        """
        let successJson = """
        {"object": "list", "data": []}
        """

        MockURLProtocol.reset()
        MockURLProtocol.mockResponses = [
            (errorJson.data(using: .utf8)!, HTTPURLResponse(url: URL(string: "https://api.openai.com/v1")!, statusCode: 500, httpVersion: nil, headerFields: nil)!),
            (successJson.data(using: .utf8)!, HTTPURLResponse(url: URL(string: "https://api.openai.com/v1")!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        ]

        let client = makeMockClientWithRetry(maxRetries: 2)
        _ = try await client.models.list()
        #expect(MockURLProtocol.requestCount == 2)
    }

    @Test func noRetryWhenMaxRetriesIsZero() async throws {
        let errorJson = """
        {"error": {"message": "Rate limit exceeded", "type": "rate_limit_error", "param": null, "code": null}}
        """

        MockURLProtocol.reset()
        MockURLProtocol.mockResponses = [
            (errorJson.data(using: .utf8)!, HTTPURLResponse(url: URL(string: "https://api.openai.com/v1")!, statusCode: 429, httpVersion: nil, headerFields: nil)!)
        ]

        let client = makeMockClientWithRetry(maxRetries: 0)
        do {
            _ = try await client.models.list()
            #expect(Bool(false), "Should have thrown")
        } catch let error as OpenAIError {
            if case .rateLimitError = error {
                // Expected
            } else {
                #expect(Bool(false), "Wrong error type: \(error)")
            }
        }
        #expect(MockURLProtocol.requestCount == 1)
    }

    @Test func noRetryOn401() async throws {
        let errorJson = """
        {"error": {"message": "Invalid API key", "type": "invalid_request_error", "param": null, "code": "invalid_api_key"}}
        """

        MockURLProtocol.reset()
        MockURLProtocol.mockResponses = [
            (errorJson.data(using: .utf8)!, HTTPURLResponse(url: URL(string: "https://api.openai.com/v1")!, statusCode: 401, httpVersion: nil, headerFields: nil)!)
        ]

        let client = makeMockClientWithRetry(maxRetries: 2)
        do {
            _ = try await client.models.list()
            #expect(Bool(false), "Should have thrown")
        } catch let error as OpenAIError {
            if case .authenticationError = error {
                // Expected
            } else {
                #expect(Bool(false), "Wrong error type: \(error)")
            }
        }
        #expect(MockURLProtocol.requestCount == 1)
    }

    // MARK: - URLError → OpenAIError Mapping (T-006)

    @Test func urlErrorTimedOutThrowsTimeout() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.mockError = URLError(.timedOut)
        let client = makeMockClientWithRetry(maxRetries: 0)
        do {
            _ = try await client.models.list()
            #expect(Bool(false), "Should have thrown")
        } catch let error as OpenAIError {
            #expect(error == .timeout)
        }
    }

    @Test func urlErrorNotConnectedThrowsConnectionError() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.mockError = URLError(.notConnectedToInternet)
        let client = makeMockClientWithRetry(maxRetries: 0)
        do {
            _ = try await client.models.list()
            #expect(Bool(false), "Should have thrown")
        } catch let error as OpenAIError {
            if case .connectionError = error {
                // Expected
            } else {
                #expect(Bool(false), "Expected connectionError, got: \(error)")
            }
        }
    }

    @Test func urlErrorCannotConnectToHostThrowsConnectionError() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.mockError = URLError(.cannotConnectToHost)
        let client = makeMockClientWithRetry(maxRetries: 0)
        do {
            _ = try await client.models.list()
            #expect(Bool(false), "Should have thrown")
        } catch let error as OpenAIError {
            if case .connectionError = error {
                // Expected
            } else {
                #expect(Bool(false), "Expected connectionError, got: \(error)")
            }
        }
    }

    // MARK: - Transient URLError Retry

    @Test func transientURLErrorRetriesThenSucceeds() async throws {
        let successJson = """
        {"object": "list", "data": []}
        """
        MockURLProtocol.reset()
        MockURLProtocol.mockSequence = [
            .error(URLError(.timedOut)),
            .response(
                successJson.data(using: .utf8)!,
                HTTPURLResponse(url: URL(string: "https://api.openai.com/v1")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            )
        ]
        let client = makeMockClientWithRetry(maxRetries: 2, retryDelay: 0.001)
        _ = try await client.models.list()
        #expect(MockURLProtocol.requestCount == 2)
    }

    // MARK: - Retry-After Header (T-008)

    @Test func retryRespectsRetryAfterNumericHeader() async throws {
        let errorJson = """
        {"error": {"message": "Rate limit exceeded", "type": "rate_limit_error", "param": null, "code": null}}
        """
        let successJson = """
        {"object": "list", "data": []}
        """
        MockURLProtocol.reset()
        MockURLProtocol.mockResponses = [
            (errorJson.data(using: .utf8)!, HTTPURLResponse(url: URL(string: "https://api.openai.com/v1")!, statusCode: 429, httpVersion: nil, headerFields: ["Retry-After": "1"])!),
            (successJson.data(using: .utf8)!, HTTPURLResponse(url: URL(string: "https://api.openai.com/v1")!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        ]
        let client = makeMockClientWithRetry(maxRetries: 2, retryDelay: 0.001)
        let start = Date()
        _ = try await client.models.list()
        let elapsed = Date().timeIntervalSince(start)
        #expect(elapsed >= 0.9, "Should have waited ~1s from Retry-After header")
        #expect(MockURLProtocol.requestCount == 2)
    }

    // MARK: - Error Body Fallback

    @Test func nonJsonErrorBodyFallsBackToRawString() async throws {
        let rawBody = "Bad Gateway"
        MockURLProtocol.reset()
        MockURLProtocol.mockResponse = (
            rawBody.data(using: .utf8)!,
            HTTPURLResponse(url: URL(string: "https://api.openai.com/v1")!, statusCode: 502, httpVersion: nil, headerFields: nil)!
        )
        let client = makeMockClientWithRetry(maxRetries: 0)
        do {
            _ = try await client.models.list()
            #expect(Bool(false), "Should have thrown")
        } catch let error as OpenAIError {
            if case .internalServerError(let message) = error {
                #expect(message == "Bad Gateway")
            } else {
                #expect(Bool(false), "Expected internalServerError, got: \(error)")
            }
        }
    }

    // MARK: - Path Validation

    @Test func validatePathComponentRejectsSlash() async throws {
        do {
            _ = try "foo/bar".validatePathComponent()
            #expect(Bool(false), "Should have thrown")
        } catch let error as OpenAIError {
            if case .apiError(_, let message, _, _) = error {
                #expect(message.contains("invalid"))
            } else {
                #expect(Bool(false), "Wrong error: \(error)")
            }
        }
    }

    @Test func validatePathComponentRejectsQueryChars() async throws {
        for char in ["?", "#", "%"] {
            do {
                _ = try "foo\(char)bar".validatePathComponent()
                #expect(Bool(false), "Should have thrown for \(char)")
            } catch is OpenAIError {
                // Expected
            }
        }
    }

    // MARK: - Streaming Retry (B-02)

    @Test func streamingRetryOn429ThenSuccess() async throws {
        let errorJson = """
        {"error": {"message": "Rate limit exceeded", "type": "rate_limit_error", "param": null, "code": null}}
        """
        let ssePayload = """
        data: {"id":"chatcmpl-stream-1","object":"chat.completion.chunk","created":1234567890,"model":"gpt-4o","choices":[{"index":0,"delta":{"role":"assistant","content":"Hello"},"finish_reason":"stop"}]}

        data: [DONE]

        """
        MockURLProtocol.reset()
        MockURLProtocol.mockResponses = [
            (errorJson.data(using: .utf8)!, HTTPURLResponse(url: URL(string: "https://api.openai.com/v1")!, statusCode: 429, httpVersion: nil, headerFields: nil)!),
            (ssePayload.data(using: .utf8)!, HTTPURLResponse(url: URL(string: "https://api.openai.com/v1")!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        ]

        let client = makeMockClientWithRetry(maxRetries: 2, retryDelay: 0.001)
        let stream = try await client.chat.completions.createStream(
            model: "gpt-4o",
            messages: [.user("Hello!")]
        )

        var chunks: [ChatCompletionChunk] = []
        for try await chunk in stream {
            chunks.append(chunk)
        }

        #expect(MockURLProtocol.requestCount == 2, "Expected 1 retry after 429")
        #expect(chunks.count == 1)
        #expect(chunks.first?.choices.first?.delta?.content == "Hello")
    }

    @Test func streamingRetryOn500ThenSuccess() async throws {
        let errorJson = """
        {"error": {"message": "Server error", "type": "server_error", "param": null, "code": null}}
        """
        let ssePayload = """
        data: {"id":"chatcmpl-stream-2","object":"chat.completion.chunk","created":1234567890,"model":"gpt-4o","choices":[{"index":0,"delta":{"role":"assistant","content":"OK"},"finish_reason":"stop"}]}

        data: [DONE]

        """
        MockURLProtocol.reset()
        MockURLProtocol.mockResponses = [
            (errorJson.data(using: .utf8)!, HTTPURLResponse(url: URL(string: "https://api.openai.com/v1")!, statusCode: 500, httpVersion: nil, headerFields: nil)!),
            (ssePayload.data(using: .utf8)!, HTTPURLResponse(url: URL(string: "https://api.openai.com/v1")!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        ]

        let client = makeMockClientWithRetry(maxRetries: 2, retryDelay: 0.001)
        let stream = try await client.chat.completions.createStream(
            model: "gpt-4o",
            messages: [.user("Hello!")]
        )

        var chunks: [ChatCompletionChunk] = []
        for try await chunk in stream {
            chunks.append(chunk)
        }

        #expect(MockURLProtocol.requestCount == 2, "Expected 1 retry after 500")
        #expect(chunks.count == 1)
        #expect(chunks.first?.choices.first?.delta?.content == "OK")
    }

    @Test func streamingNoRetryOn401() async throws {
        let errorJson = """
        {"error": {"message": "Invalid API key", "type": "invalid_request_error", "param": null, "code": "invalid_api_key"}}
        """
        MockURLProtocol.reset()
        MockURLProtocol.mockResponses = [
            (errorJson.data(using: .utf8)!, HTTPURLResponse(url: URL(string: "https://api.openai.com/v1")!, statusCode: 401, httpVersion: nil, headerFields: nil)!)
        ]

        let client = makeMockClientWithRetry(maxRetries: 2, retryDelay: 0.001)
        do {
            let stream = try await client.chat.completions.createStream(
                model: "gpt-4o",
                messages: [.user("Hello!")]
            )
            for try await _ in stream {}
            #expect(Bool(false), "Should have thrown")
        } catch let error as OpenAIError {
            if case .authenticationError = error {
                // Expected
            } else {
                #expect(Bool(false), "Expected authenticationError, got: \(error)")
            }
        }
        #expect(MockURLProtocol.requestCount == 1, "Should not retry 401")
    }

}