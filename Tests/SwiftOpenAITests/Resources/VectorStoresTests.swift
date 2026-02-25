import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SwiftOpenAI

// MARK: - Tests

extension MockAPITests {

    @Test func retrieveVectorStore() async throws {
        let json = """
        {
            "id": "vs-123",
            "object": "vector_store",
            "created_at": 1234567890,
            "name": "My Store",
            "status": "completed",
            "usage_bytes": 1024,
            "file_counts": {
                "in_progress": 0,
                "completed": 5,
                "failed": 0,
                "cancelled": 0,
                "total": 5
            }
        }
        """
        let client = makeMockClient(json: json)
        let store = try await client.vectorStores.retrieve("vs-123")

        #expect(store.id == "vs-123")
        #expect(store.object == "vector_store")
        #expect(store.createdAt == 1234567890)
        #expect(store.name == "My Store")
        #expect(store.status == "completed")
        #expect(store.usageBytes == 1024)
        #expect(store.fileCounts?.completed == 5)
        #expect(store.fileCounts?.total == 5)
        #expect(store.fileCounts?.inProgress == 0)
    }

    @Test func listVectorStores() async throws {
        let json = """
        {
            "object": "list",
            "data": [
                {
                    "id": "vs-123",
                    "object": "vector_store",
                    "created_at": 1234567890,
                    "name": "My Store",
                    "status": "completed"
                }
            ],
            "has_more": false
        }
        """
        let client = makeMockClient(json: json)
        let response = try await client.vectorStores.list()

        #expect(response.object == "list")
        #expect(response.data.count == 1)
        #expect(response.data[0].id == "vs-123")
        #expect(response.hasMore == false)
    }

    @Test func deleteVectorStore() async throws {
        let json = """
        {
            "id": "vs-123",
            "object": "vector_store.deleted",
            "deleted": true
        }
        """
        let client = makeMockClient(json: json)
        let result = try await client.vectorStores.delete("vs-123")

        #expect(result.id == "vs-123")
        #expect(result.deleted == true)
    }

    @Test func retrieveVectorStoreFile() async throws {
        let json = """
        {
            "id": "file-abc",
            "object": "vector_store.file",
            "created_at": 1234567890,
            "vector_store_id": "vs-123",
            "status": "completed",
            "usage_bytes": 512
        }
        """
        let client = makeMockClient(json: json)
        let file = try await client.vectorStores.files.retrieve(
            vectorStoreId: "vs-123", fileId: "file-abc"
        )

        #expect(file.id == "file-abc")
        #expect(file.vectorStoreId == "vs-123")
        #expect(file.status == "completed")
        #expect(file.usageBytes == 512)
    }

    @Test func createVectorStore() async throws {
        let json = """
        {
            "id": "vs-new",
            "object": "vector_store",
            "created_at": 1234567890,
            "name": "Test Store",
            "status": "completed",
            "usage_bytes": 0
        }
        """
        let client = makeMockClient(json: json)
        let store = try await client.vectorStores.create(name: "Test Store")

        #expect(store.id == "vs-new")
        #expect(store.name == "Test Store")
        #expect(store.status == "completed")
        #expect(MockURLProtocol.lastRequest?.url?.path.contains("vector_stores") == true)
    }

    @Test func updateVectorStore() async throws {
        let json = """
        {
            "id": "vs-123",
            "object": "vector_store",
            "created_at": 1234567890,
            "name": "Updated Store",
            "status": "completed"
        }
        """
        let client = makeMockClient(json: json)
        let store = try await client.vectorStores.update("vs-123", name: "Updated Store")

        #expect(store.id == "vs-123")
        #expect(store.name == "Updated Store")
        #expect(MockURLProtocol.lastRequest?.url?.path.contains("vector_stores") == true)
    }

    @Test func createVectorStoreFile() async throws {
        let json = """
        {
            "id": "vsfile-001",
            "object": "vector_store.file",
            "created_at": 1234567890,
            "vector_store_id": "vs-123",
            "status": "in_progress",
            "usage_bytes": 0
        }
        """
        let client = makeMockClient(json: json)
        let file = try await client.vectorStores.files.create(
            vectorStoreId: "vs-123", fileId: "file-abc"
        )

        #expect(file.id == "vsfile-001")
        #expect(file.vectorStoreId == "vs-123")
        #expect(file.status == "in_progress")
        #expect(MockURLProtocol.lastRequest?.url?.path.contains("vector_stores") == true)
    }

    @Test func listVectorStoreFiles() async throws {
        let json = """
        {
            "object": "list",
            "data": [
                {
                    "id": "vsfile-001",
                    "object": "vector_store.file",
                    "created_at": 1234567890,
                    "vector_store_id": "vs-123",
                    "status": "completed",
                    "usage_bytes": 512
                }
            ],
            "has_more": false
        }
        """
        let client = makeMockClient(json: json)
        let response = try await client.vectorStores.files.list(vectorStoreId: "vs-123")

        #expect(response.data.count == 1)
        #expect(response.hasMore == false)
    }

    @Test func deleteVectorStoreFile() async throws {
        let json = """
        {
            "id": "file-abc",
            "object": "vector_store.file.deleted",
            "deleted": true
        }
        """
        let client = makeMockClient(json: json)
        let result = try await client.vectorStores.files.delete(
            vectorStoreId: "vs-123", fileId: "file-abc"
        )

        #expect(result.id == "file-abc")
        #expect(result.deleted == true)
    }
}
