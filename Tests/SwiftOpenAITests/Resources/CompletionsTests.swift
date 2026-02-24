import Foundation
import Testing
@testable import SwiftOpenAI

// MARK: - Tests

extension MockAPITests {

    @Test func createCompletion() async throws {
        let json = """
        {
            "id": "cmpl-123",
            "object": "text_completion",
            "created": 1234567890,
            "model": "gpt-3.5-turbo-instruct",
            "choices": [
                {
                    "index": 0,
                    "text": " world!",
                    "finish_reason": "stop"
                }
            ],
            "usage": {
                "prompt_tokens": 5,
                "completion_tokens": 2,
                "total_tokens": 7
            }
        }
        """
        let client = makeMockClient(json: json)
        let response = try await client.completions.create(
            model: "gpt-3.5-turbo-instruct",
            prompt: .string("Hello")
        )

        #expect(response.id == "cmpl-123")
        #expect(response.object == "text_completion")
        #expect(response.created == 1234567890)
        #expect(response.model == "gpt-3.5-turbo-instruct")
        #expect(response.choices.count == 1)
        #expect(response.choices[0].index == 0)
        #expect(response.choices[0].text == " world!")
        #expect(response.choices[0].finishReason == "stop")
        #expect(response.usage?.promptTokens == 5)
        #expect(response.usage?.completionTokens == 2)
        #expect(response.usage?.totalTokens == 7)

        let requestURL = MockURLProtocol.lastRequest?.url?.absoluteString
        #expect(requestURL?.contains("completions") == true)
    }
}
