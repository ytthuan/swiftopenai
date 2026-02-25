import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
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

    @Test func createFile() async throws {
        let json = """
        {
            "id": "file-new",
            "object": "file",
            "bytes": 2048,
            "created_at": 1234567890,
            "filename": "training.jsonl",
            "purpose": "fine-tune",
            "status": "uploaded"
        }
        """
        let client = makeMockClient(json: json)
        let file = try await client.files.create(
            file: Data("test-data".utf8),
            filename: "training.jsonl",
            purpose: "fine-tune"
        )

        #expect(file.id == "file-new")
        #expect(file.filename == "training.jsonl")
        #expect(file.purpose == "fine-tune")

        let requestURL = MockURLProtocol.lastRequest?.url?.path
        #expect(requestURL?.contains("files") == true)

        #expect(MockURLProtocol.lastRequestBody != nil)
        #expect(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data") == true)
    }

    @Test func fileContent() async throws {
        let client = makeMockClient(json: "file content here")
        let data = try await client.files.content("file-abc123")

        #expect(String(data: data, encoding: .utf8) == "file content here")

        let requestURL = MockURLProtocol.lastRequest?.url?.path
        #expect(requestURL?.contains("files") == true)
        #expect(requestURL?.contains("content") == true)
    }
}
