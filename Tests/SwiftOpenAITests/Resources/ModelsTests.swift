import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SwiftOpenAI

// MARK: - Tests

extension MockAPITests {

    @Test func listModels() async throws {
        let json = """
        {
            "object": "list",
            "data": [
                {
                    "id": "gpt-4o",
                    "object": "model",
                    "created": 1715367049,
                    "owned_by": "system"
                },
                {
                    "id": "gpt-3.5-turbo",
                    "object": "model",
                    "created": 1677610602,
                    "owned_by": "openai"
                }
            ],
            "has_more": false
        }
        """
        let client = makeMockClient(json: json)
        let response = try await client.models.list()

        #expect(response.object == "list")
        #expect(response.data.count == 2)
        #expect(response.data[0].id == "gpt-4o")
        #expect(response.data[0].ownedBy == "system")
        #expect(response.data[1].id == "gpt-3.5-turbo")
        #expect(response.data[1].ownedBy == "openai")
        #expect(response.hasMore == false)
    }

    @Test func retrieveModel() async throws {
        let json = """
        {
            "id": "gpt-4o",
            "object": "model",
            "created": 1715367049,
            "owned_by": "system"
        }
        """
        let client = makeMockClient(json: json)
        let model = try await client.models.retrieve("gpt-4o")

        #expect(model.id == "gpt-4o")
        #expect(model.object == "model")
        #expect(model.created == 1715367049)
        #expect(model.ownedBy == "system")
    }

    @Test func deleteModel() async throws {
        let json = """
        {
            "id": "ft:gpt-3.5-turbo:my-org:custom:abc123",
            "object": "model",
            "deleted": true
        }
        """
        let client = makeMockClient(json: json)
        let result = try await client.models.delete("ft:gpt-3.5-turbo:my-org:custom:abc123")

        #expect(result.id == "ft:gpt-3.5-turbo:my-org:custom:abc123")
        #expect(result.object == "model")
        #expect(result.deleted == true)
    }
}
