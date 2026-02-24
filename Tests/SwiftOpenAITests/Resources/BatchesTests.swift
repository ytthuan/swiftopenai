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
}
