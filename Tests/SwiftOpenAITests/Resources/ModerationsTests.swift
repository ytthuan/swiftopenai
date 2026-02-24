import Foundation
import Testing
@testable import SwiftOpenAI

// MARK: - Tests

extension MockAPITests {

    @Test func createModeration() async throws {
    let json = """
    {
      "id": "modr-123",
      "model": "text-moderation-007",
      "results": [{
        "flagged": false,
        "categories": {
          "hate": false,
          "hate/threatening": false,
          "harassment": false,
          "harassment/threatening": false,
          "self-harm": false,
          "self-harm/intent": false,
          "self-harm/instructions": false,
          "sexual": false,
          "sexual/minors": false,
          "violence": false,
          "violence/graphic": false
        },
        "category_scores": {
          "hate": 0.001,
          "hate/threatening": 0.001,
          "harassment": 0.001,
          "harassment/threatening": 0.001,
          "self-harm": 0.001,
          "self-harm/intent": 0.001,
          "self-harm/instructions": 0.001,
          "sexual": 0.001,
          "sexual/minors": 0.001,
          "violence": 0.001,
          "violence/graphic": 0.001
        }
      }]
    }
    """

    let client = makeMockClient(json: json)
    let result = try await client.moderations.create(input: .string("Hello, world!"))

    #expect(result.id == "modr-123")
    #expect(result.model == "text-moderation-007")
    #expect(result.results.count == 1)

    let moderation = result.results[0]
    #expect(moderation.flagged == false)
    #expect(moderation.categories.hate == false)
    #expect(moderation.categories.hateThreatening == false)
    #expect(moderation.categories.selfHarm == false)
    #expect(moderation.categoryScores.hate == 0.001)
    #expect(moderation.categoryScores.hateThreatening == 0.001)
    #expect(moderation.categoryScores.selfHarm == 0.001)
}

}
