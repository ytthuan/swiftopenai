import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import SwiftOpenAI

// MARK: - Tests

extension MockAPITests {

    @Test func createEmbedding() async throws {
    let json = """
    {
        "object": "list",
        "data": [
            {
                "object": "embedding",
                "embedding": [0.0023064255, -0.009327292, 0.015797347],
                "index": 0
            }
        ],
        "model": "text-embedding-3-small",
        "usage": {
            "prompt_tokens": 5,
            "total_tokens": 5
        }
    }
    """
    let client = makeMockClient(json: json)
    let response = try await client.embeddings.create(
        model: "text-embedding-3-small",
        input: .string("Hello world")
    )

    #expect(response.object == "list")
    #expect(response.model == "text-embedding-3-small")
    #expect(response.data.count == 1)
    #expect(response.data[0].object == "embedding")
    #expect(response.data[0].index == 0)
    #expect(response.data[0].embedding.count == 3)
    #expect(response.usage.promptTokens == 5)
    #expect(response.usage.totalTokens == 5)

    let requestURL = MockURLProtocol.lastRequest?.url?.absoluteString
    #expect(requestURL?.contains("embeddings") == true)
}

    @Test func createEmbeddingWithDimensions() async throws {
    let json = """
    {
        "object": "list",
        "data": [
            {
                "object": "embedding",
                "embedding": [0.1, 0.2],
                "index": 0
            }
        ],
        "model": "text-embedding-3-small",
        "usage": {
            "prompt_tokens": 2,
            "total_tokens": 2
        }
    }
    """
    let client = makeMockClient(json: json)
    let response = try await client.embeddings.create(
        model: "text-embedding-3-small",
        input: .strings(["Hello", "World"]),
        dimensions: 256
    )

    #expect(response.data[0].embedding.count == 2)
    #expect(response.usage.promptTokens == 2)

    // Verify the request body includes dimensions
    let requestBody = MockURLProtocol.lastRequestBody
    let bodyJSON = try #require(requestBody.flatMap {
        try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
    })
    #expect(bodyJSON["dimensions"] as? Int == 256)
    #expect(bodyJSON["model"] as? String == "text-embedding-3-small")
}

}
