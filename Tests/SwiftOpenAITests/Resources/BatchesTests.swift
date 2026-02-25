import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SwiftOpenAI

// MARK: - Tests

extension MockAPITests {

    @Test func retrieveBatch() async throws {
        let json = """
        {
            "id": "batch-123",
            "object": "batch",
            "endpoint": "/v1/chat/completions",
            "input_file_id": "file-abc",
            "completion_window": "24h",
            "status": "completed",
            "output_file_id": "file-def",
            "error_file_id": null,
            "created_at": 1234567890,
            "request_counts": {
                "total": 100,
                "completed": 95,
                "failed": 5
            }
        }
        """
        let client = makeMockClient(json: json)
        let batch = try await client.batches.retrieve("batch-123")

        #expect(batch.id == "batch-123")
        #expect(batch.object == "batch")
        #expect(batch.endpoint == "/v1/chat/completions")
        #expect(batch.inputFileId == "file-abc")
        #expect(batch.completionWindow == "24h")
        #expect(batch.status == "completed")
        #expect(batch.outputFileId == "file-def")
        #expect(batch.errorFileId == nil)
        #expect(batch.createdAt == 1234567890)
        #expect(batch.requestCounts?.total == 100)
        #expect(batch.requestCounts?.completed == 95)
        #expect(batch.requestCounts?.failed == 5)
    }

    @Test func createBatch() async throws {
        let json = """
        {
            "id": "batch-456",
            "object": "batch",
            "endpoint": "/v1/chat/completions",
            "input_file_id": "file-abc",
            "completion_window": "24h",
            "status": "validating",
            "output_file_id": null,
            "error_file_id": null,
            "created_at": 1234567890
        }
        """
        let client = makeMockClient(json: json)
        let batch = try await client.batches.create(
            inputFileId: "file-abc",
            endpoint: "/v1/chat/completions",
            completionWindow: "24h"
        )

        #expect(batch.id == "batch-456")
        #expect(batch.status == "validating")
        #expect(MockURLProtocol.lastRequest?.url?.path.contains("batches") == true)
    }

    @Test func listBatches() async throws {
        let json = """
        {
            "object": "list",
            "data": [
                {
                    "id": "batch-001",
                    "object": "batch",
                    "endpoint": "/v1/chat/completions",
                    "input_file_id": "file-abc",
                    "completion_window": "24h",
                    "status": "completed",
                    "output_file_id": null,
                    "error_file_id": null,
                    "created_at": 1234567890
                }
            ],
            "has_more": false
        }
        """
        let client = makeMockClient(json: json)
        let list = try await client.batches.list()

        #expect(list.data.count == 1)
        #expect(list.hasMore == false)
    }

    @Test func cancelBatch() async throws {
        let json = """
        {
            "id": "batch-123",
            "object": "batch",
            "endpoint": "/v1/chat/completions",
            "input_file_id": "file-abc",
            "completion_window": "24h",
            "status": "cancelling",
            "output_file_id": null,
            "error_file_id": null,
            "created_at": 1234567890
        }
        """
        let client = makeMockClient(json: json)
        let batch = try await client.batches.cancel("batch-123")

        #expect(batch.status == "cancelling")
        #expect(MockURLProtocol.lastRequest?.url?.path.contains("cancel") == true)
    }
}
