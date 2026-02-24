import Testing
import Foundation
@testable import SwiftOpenAI

// MARK: - Tests

extension MockAPITests {

    @Test func listFiles() async throws {
        let json = """
        {
            "object": "list",
            "data": [
                {
                    "id": "file-abc123",
                    "object": "file",
                    "bytes": 1024,
                    "created_at": 1234567890,
                    "filename": "data.jsonl",
                    "purpose": "fine-tune",
                    "status": "processed"
                }
            ],
            "has_more": false
        }
        """
        let client = makeMockClient(json: json)
        let response = try await client.files.list()

        #expect(response.object == "list")
        #expect(response.data.count == 1)
        #expect(response.data[0].id == "file-abc123")
        #expect(response.data[0].bytes == 1024)
        #expect(response.data[0].filename == "data.jsonl")
        #expect(response.data[0].purpose == "fine-tune")
        #expect(response.data[0].status == "processed")
    }

    @Test func retrieveFile() async throws {
        let json = """
        {
            "id": "file-abc123",
            "object": "file",
            "bytes": 1024,
            "created_at": 1234567890,
            "filename": "data.jsonl",
            "purpose": "fine-tune",
            "status": "processed"
        }
        """
        let client = makeMockClient(json: json)
        let file = try await client.files.retrieve("file-abc123")

        #expect(file.id == "file-abc123")
        #expect(file.object == "file")
        #expect(file.bytes == 1024)
        #expect(file.createdAt == 1234567890)
        #expect(file.filename == "data.jsonl")
        #expect(file.purpose == "fine-tune")
        #expect(file.status == "processed")
    }

    @Test func deleteFile() async throws {
        let json = """
        {
            "id": "file-abc123",
            "object": "file",
            "deleted": true
        }
        """
        let client = makeMockClient(json: json)
        let result = try await client.files.delete("file-abc123")

        #expect(result.id == "file-abc123")
        #expect(result.object == "file")
        #expect(result.deleted == true)
    }
}
