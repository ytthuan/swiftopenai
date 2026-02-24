import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SwiftOpenAI

// MARK: - Tests

extension MockAPITests {

    @Test func retrieveFineTuningJob() async throws {
        let json = """
        {
            "id": "ftjob-123",
            "object": "fine_tuning.job",
            "created_at": 1234567890,
            "model": "gpt-4o-mini-2024-07-18",
            "fine_tuned_model": null,
            "organization_id": "org-123",
            "status": "validating_files",
            "training_file": "file-abc123",
            "validation_file": null,
            "trained_tokens": null,
            "seed": 42
        }
        """
        let client = makeMockClient(json: json)
        let job = try await client.fineTuning.jobs.retrieve("ftjob-123")

        #expect(job.id == "ftjob-123")
        #expect(job.object == "fine_tuning.job")
        #expect(job.createdAt == 1234567890)
        #expect(job.model == "gpt-4o-mini-2024-07-18")
        #expect(job.fineTunedModel == nil)
        #expect(job.organizationId == "org-123")
        #expect(job.status == "validating_files")
        #expect(job.trainingFile == "file-abc123")
        #expect(job.validationFile == nil)
        #expect(job.trainedTokens == nil)
        #expect(job.seed == 42)
    }

    @Test func listFineTuningJobs() async throws {
        let json = """
        {
            "object": "list",
            "data": [
                {
                    "id": "ftjob-123",
                    "object": "fine_tuning.job",
                    "created_at": 1234567890,
                    "model": "gpt-4o-mini-2024-07-18",
                    "status": "succeeded",
                    "training_file": "file-abc123",
                    "seed": 42
                }
            ],
            "has_more": false
        }
        """
        let client = makeMockClient(json: json)
        let response = try await client.fineTuning.jobs.list()

        #expect(response.object == "list")
        #expect(response.data.count == 1)
        #expect(response.data[0].id == "ftjob-123")
        #expect(response.data[0].status == "succeeded")
        #expect(response.hasMore == false)
    }
}
