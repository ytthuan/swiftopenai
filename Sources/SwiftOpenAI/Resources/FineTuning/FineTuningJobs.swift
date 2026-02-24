import Foundation

/// Access the OpenAI Fine-tuning Jobs API.
public struct FineTuningJobs: Sendable {

    private let client: HTTPClient

    init(client: HTTPClient) { self.client = client }

    /// Creates a fine-tuning job.
    ///
    /// - Parameters:
    ///   - model: The name of the model to fine-tune.
    ///   - trainingFile: The ID of the uploaded training file.
    ///   - validationFile: The ID of an optional uploaded validation file.
    ///   - hyperparameters: Hyperparameter overrides for the job.
    ///   - suffix: A string suffix for the fine-tuned model name.
    ///   - seed: Random seed for reproducibility.
    /// - Returns: The created ``FineTuningJob``.
    public func create(
        model: String,
        trainingFile: String,
        validationFile: String? = nil,
        hyperparameters: HyperparametersParam? = nil,
        suffix: String? = nil,
        seed: Int? = nil
    ) async throws -> FineTuningJob {
        let params = FineTuningJobCreateParams(
            model: model,
            trainingFile: trainingFile,
            validationFile: validationFile,
            hyperparameters: hyperparameters,
            suffix: suffix,
            seed: seed
        )
        return try await client.post(path: "fine_tuning/jobs", body: params)
    }

    /// Retrieves a fine-tuning job by ID.
    ///
    /// - Parameter id: The fine-tuning job identifier.
    /// - Returns: The ``FineTuningJob``.
    public func retrieve(_ id: String) async throws -> FineTuningJob {
        let validatedID = try id.validatePathComponent()
        return try await client.get(path: "fine_tuning/jobs/\(validatedID)")
    }

    /// Lists fine-tuning jobs.
    ///
    /// - Parameters:
    ///   - after: Cursor for pagination.
    ///   - limit: Maximum number of results to return.
    /// - Returns: A ``ListResponse`` of ``FineTuningJob``.
    public func list(after: String? = nil, limit: Int? = nil) async throws -> ListResponse<FineTuningJob> {
        var queryItems: [URLQueryItem] = []
        if let after { queryItems.append(URLQueryItem(name: "after", value: after)) }
        if let limit { queryItems.append(URLQueryItem(name: "limit", value: String(limit))) }
        return try await client.get(path: "fine_tuning/jobs", queryItems: queryItems.isEmpty ? nil : queryItems)
    }

    /// Cancels a fine-tuning job.
    ///
    /// - Parameter id: The fine-tuning job identifier.
    /// - Returns: The cancelled ``FineTuningJob``.
    public func cancel(_ id: String) async throws -> FineTuningJob {
        let validatedID = try id.validatePathComponent()
        return try await client.post(path: "fine_tuning/jobs/\(validatedID)/cancel", body: nil as String?)
    }

    /// Lists events for a fine-tuning job.
    ///
    /// - Parameters:
    ///   - id: The fine-tuning job identifier.
    ///   - after: Cursor for pagination.
    ///   - limit: Maximum number of results to return.
    /// - Returns: A ``ListResponse`` of ``FineTuningEvent``.
    public func listEvents(
        _ id: String,
        after: String? = nil,
        limit: Int? = nil
    ) async throws -> ListResponse<FineTuningEvent> {
        let validatedID = try id.validatePathComponent()
        var queryItems: [URLQueryItem] = []
        if let after { queryItems.append(URLQueryItem(name: "after", value: after)) }
        if let limit { queryItems.append(URLQueryItem(name: "limit", value: String(limit))) }
        return try await client.get(
            path: "fine_tuning/jobs/\(validatedID)/events",
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
    }

    /// Lists checkpoints for a fine-tuning job.
    ///
    /// - Parameters:
    ///   - id: The fine-tuning job identifier.
    ///   - after: Cursor for pagination.
    ///   - limit: Maximum number of results to return.
    /// - Returns: A ``ListResponse`` of ``FineTuningCheckpoint``.
    public func listCheckpoints(
        _ id: String,
        after: String? = nil,
        limit: Int? = nil
    ) async throws -> ListResponse<FineTuningCheckpoint> {
        let validatedID = try id.validatePathComponent()
        var queryItems: [URLQueryItem] = []
        if let after { queryItems.append(URLQueryItem(name: "after", value: after)) }
        if let limit { queryItems.append(URLQueryItem(name: "limit", value: String(limit))) }
        return try await client.get(
            path: "fine_tuning/jobs/\(validatedID)/checkpoints",
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
    }
}
