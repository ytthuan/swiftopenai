import Foundation

/// Namespace for Fine-tuning API resources.
public struct FineTuning: Sendable {
    /// Access fine-tuning jobs.
    public let jobs: FineTuningJobs

    init(client: HTTPClient) {
        self.jobs = FineTuningJobs(client: client)
    }
}
