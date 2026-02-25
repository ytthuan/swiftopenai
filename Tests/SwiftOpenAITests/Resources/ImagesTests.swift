import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import SwiftOpenAI

// MARK: - Tests

extension MockAPITests {

    @Test func generateImage() async throws {
        let json = """
        {
            "created": 1234567890,
            "data": [
                {
                    "url": "https://example.com/image.png",
                    "revised_prompt": "A cute orange cat sitting on a windowsill"
                }
            ]
        }
        """
        let client = makeMockClient(json: json)
        let response = try await client.images.generate(
            prompt: "A cute cat",
            model: "dall-e-3"
        )

        #expect(response.created == 1234567890)
        #expect(response.data.count == 1)
        #expect(response.data[0].url == "https://example.com/image.png")
        #expect(response.data[0].revisedPrompt == "A cute orange cat sitting on a windowsill")
        #expect(response.data[0].b64Json == nil)

        let requestURL = MockURLProtocol.lastRequest?.url?.absoluteString
        #expect(requestURL?.contains("images/generations") == true)
    }

    @Test func editImage() async throws {
        let json = """
        {
            "created": 1234567890,
            "data": [
                {
                    "url": "https://example.com/edited.png"
                }
            ]
        }
        """
        let client = makeMockClient(json: json)
        let response = try await client.images.edit(
            image: Data("fake-image".utf8),
            prompt: "Add a hat"
        )

        #expect(response.created == 1234567890)
        #expect(response.data.count == 1)
        #expect(response.data[0].url == "https://example.com/edited.png")

        let requestURL = MockURLProtocol.lastRequest?.url?.path
        #expect(requestURL?.contains("images/edits") == true)

        #expect(MockURLProtocol.lastRequestBody != nil)
        if let body = MockURLProtocol.lastRequestBody {
            let bodyString = String(data: body, encoding: .utf8)
            #expect(bodyString?.contains("fake-image") == true)
        }
        #expect(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data") == true)
    }

}
