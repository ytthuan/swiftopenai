import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SwiftOpenAI

// MARK: - Tests

extension MockAPITests {

    @Test func createUpload() async throws {
        let json = """
        {
            "id": "upload-123",
            "object": "upload",
            "bytes": 1048576,
            "created_at": 1234567890,
            "filename": "data.jsonl",
            "purpose": "fine-tune",
            "status": "pending",
            "expires_at": 1234599999
        }
        """
        let client = makeMockClient(json: json)
        let upload = try await client.uploads.create(
            filename: "data.jsonl",
            purpose: "fine-tune",
            bytes: 1_048_576,
            mimeType: "application/jsonl"
        )

        #expect(upload.id == "upload-123")
        #expect(upload.object == "upload")
        #expect(upload.bytes == 1_048_576)
        #expect(upload.createdAt == 1234567890)
        #expect(upload.filename == "data.jsonl")
        #expect(upload.purpose == "fine-tune")
        #expect(upload.status == "pending")
        #expect(upload.expiresAt == 1234599999)
        #expect(upload.file == nil)
    }

    @Test func addUploadPart() async throws {
        let json = """
        {
            "id": "part-456",
            "object": "upload.part",
            "created_at": 1234567890,
            "upload_id": "upload-123"
        }
        """
        let client = makeMockClient(json: json)
        let part = try await client.uploads.parts.create(
            uploadId: "upload-123",
            data: Data(repeating: 0, count: 64)
        )

        #expect(part.id == "part-456")
        #expect(part.object == "upload.part")
        #expect(part.createdAt == 1234567890)
        #expect(part.uploadId == "upload-123")
    }

    @Test func completeUpload() async throws {
        let json = """
        {
            "id": "upload-123",
            "object": "upload",
            "bytes": 1048576,
            "created_at": 1234567890,
            "filename": "data.jsonl",
            "purpose": "fine-tune",
            "status": "completed",
            "expires_at": 1234599999
        }
        """
        let client = makeMockClient(json: json)
        let upload = try await client.uploads.complete(
            "upload-123",
            partIds: ["part-1", "part-2"]
        )

        #expect(upload.id == "upload-123")
        #expect(upload.status == "completed")
    }

    @Test func cancelUpload() async throws {
        let json = """
        {
            "id": "upload-123",
            "object": "upload",
            "bytes": 1048576,
            "created_at": 1234567890,
            "filename": "data.jsonl",
            "purpose": "fine-tune",
            "status": "cancelled",
            "expires_at": null
        }
        """
        let client = makeMockClient(json: json)
        let upload = try await client.uploads.cancel("upload-123")

        #expect(upload.id == "upload-123")
        #expect(upload.status == "cancelled")
        #expect(upload.expiresAt == nil)
    }
}
