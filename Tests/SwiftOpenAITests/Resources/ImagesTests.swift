import Foundation
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

}
