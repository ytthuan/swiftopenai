import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import SwiftOpenAI

/// Creates an OpenAI client configured with MockURLProtocol for testing.
///
/// - Parameters:
///   - json: The JSON string to return as the mock response body.
///   - statusCode: The HTTP status code to return (default: 200).
/// - Returns: An OpenAI client that uses the mock transport.
func makeMockClient(json: String, statusCode: Int = 200) -> OpenAI {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: config)

    MockURLProtocol.mockResponse = (
        json.data(using: .utf8)!,
        HTTPURLResponse(
            url: URL(string: "https://api.openai.com/v1")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    )

    return OpenAI(apiKey: "test-key", session: session)
}

/// Shared serialized suite for all tests that use MockURLProtocol,
/// since the static mock state is not safe for concurrent access.
@Suite(.serialized)
struct MockAPITests {}
