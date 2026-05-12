import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SwiftOpenAI

// MARK: - EntraIDTokenProvider Tests (extension of MockAPITests for serialized access)

private func makeEntraProvider(session: URLSession) -> EntraIDTokenProvider {
    EntraIDTokenProvider(
        tenantId: "test-tenant",
        clientId: "test-client",
        clientSecret: "test-secret",
        scope: "https://cognitiveservices.azure.com/.default",
        session: session
    )
}

private func makeMockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

extension MockAPITests {

    // MARK: - EntraID Happy Path

    @Test func entraIDGetTokenReturnsAccessToken() async throws {
        MockURLProtocol.reset()
        let tokenJson = """
        {"access_token": "eyJ-mock-token", "expires_in": 3600, "token_type": "Bearer"}
        """
        MockURLProtocol.mockResponse = (
            tokenJson.data(using: .utf8)!,
            HTTPURLResponse(
                url: URL(string: "https://login.microsoftonline.com/test-tenant/oauth2/v2.0/token")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
        )

        let provider = makeEntraProvider(session: makeMockSession())
        let token = try await provider.getToken()
        #expect(token == "eyJ-mock-token")
    }

    @Test func entraIDRequestBodyContainsExpectedFormFields() async throws {
        MockURLProtocol.reset()
        let tokenJson = """
        {"access_token": "tok", "expires_in": 3600, "token_type": "Bearer"}
        """
        MockURLProtocol.mockResponse = (
            tokenJson.data(using: .utf8)!,
            HTTPURLResponse(
                url: URL(string: "https://login.microsoftonline.com/test-tenant/oauth2/v2.0/token")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
        )

        let provider = makeEntraProvider(session: makeMockSession())
        _ = try await provider.getToken()

        let request = MockURLProtocol.lastRequest!
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")

        let bodyString = String(data: MockURLProtocol.lastRequestBody!, encoding: .utf8)!
        #expect(bodyString.contains("client_id=test-client"))
        #expect(bodyString.contains("client_secret=test-secret"))
        #expect(bodyString.contains("grant_type=client_credentials"))
        #expect(bodyString.contains("scope=https%3A%2F%2Fcognitiveservices.azure.com%2F.default"))
    }

    // MARK: - EntraID Caching

    @Test func entraIDSecondCallReturnsCachedToken() async throws {
        MockURLProtocol.reset()
        let tokenJson = """
        {"access_token": "cached-token", "expires_in": 3600, "token_type": "Bearer"}
        """
        MockURLProtocol.mockResponse = (
            tokenJson.data(using: .utf8)!,
            HTTPURLResponse(
                url: URL(string: "https://login.microsoftonline.com/test-tenant/oauth2/v2.0/token")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
        )

        let provider = makeEntraProvider(session: makeMockSession())
        let token1 = try await provider.getToken()
        let token2 = try await provider.getToken()

        #expect(token1 == "cached-token")
        #expect(token2 == "cached-token")
        // Only one request should have been made (second was cached)
        #expect(MockURLProtocol.requestCount == 1)
    }

    // MARK: - EntraID Error Paths

    @Test func entraIDNonSuccessStatusThrowsAuthenticationError() async throws {
        MockURLProtocol.reset()
        let errorJson = """
        {"error": "invalid_client", "error_description": "Bad credentials"}
        """
        MockURLProtocol.mockResponse = (
            errorJson.data(using: .utf8)!,
            HTTPURLResponse(
                url: URL(string: "https://login.microsoftonline.com/test-tenant/oauth2/v2.0/token")!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
        )

        let provider = makeEntraProvider(session: makeMockSession())
        do {
            _ = try await provider.getToken()
            #expect(Bool(false), "Should have thrown")
        } catch let error as OpenAIError {
            if case .authenticationError(let message) = error {
                #expect(message.contains("invalid_client"))
                #expect(message.contains("Bad credentials"))
            } else {
                #expect(Bool(false), "Expected authenticationError, got: \(error)")
            }
        }
    }

    @Test func entraIDNonSuccessUnparsableBodyThrowsStatusFallback() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.mockResponse = (
            "not json".data(using: .utf8)!,
            HTTPURLResponse(
                url: URL(string: "https://login.microsoftonline.com/test-tenant/oauth2/v2.0/token")!,
                statusCode: 403,
                httpVersion: nil,
                headerFields: nil
            )!
        )

        let provider = makeEntraProvider(session: makeMockSession())
        do {
            _ = try await provider.getToken()
            #expect(Bool(false), "Should have thrown")
        } catch let error as OpenAIError {
            if case .authenticationError(let message) = error {
                #expect(message.contains("403"))
            } else {
                #expect(Bool(false), "Expected authenticationError, got: \(error)")
            }
        }
    }

    @Test func entraIDNetworkErrorThrowsConnectionError() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.mockError = URLError(.notConnectedToInternet)

        let provider = makeEntraProvider(session: makeMockSession())
        do {
            _ = try await provider.getToken()
            #expect(Bool(false), "Should have thrown")
        } catch let error as OpenAIError {
            if case .connectionError(let message) = error {
                #expect(message.contains("Entra ID token request failed"))
            } else {
                #expect(Bool(false), "Expected connectionError, got: \(error)")
            }
        }
    }

    @Test func entraIDMalformedTokenResponseThrowsDecodingError() async throws {
        MockURLProtocol.reset()
        let badJson = """
        {"unexpected_field": "value"}
        """
        MockURLProtocol.mockResponse = (
            badJson.data(using: .utf8)!,
            HTTPURLResponse(
                url: URL(string: "https://login.microsoftonline.com/test-tenant/oauth2/v2.0/token")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
        )

        let provider = makeEntraProvider(session: makeMockSession())
        do {
            _ = try await provider.getToken()
            #expect(Bool(false), "Should have thrown")
        } catch let error as OpenAIError {
            if case .decodingError(let message) = error {
                #expect(message.contains("Entra ID token response"))
            } else {
                #expect(Bool(false), "Expected decodingError, got: \(error)")
            }
        }
    }
}
