import Foundation

/// A fine-tuning job.
public struct FineTuningJob: Codable, Sendable, Identifiable {
    public let id: String
    public let object: String
    public let createdAt: Int
    public let finishedAt: Int?
    public let model: String
    public let fineTunedModel: String?
    public let organizationId: String?
    public let status: String
    public let hyperparameters: Hyperparameters?
    public let trainingFile: String
    public let validationFile: String?
    public let trainedTokens: Int?
    public let error: FineTuningJobError?
    public let seed: Int?
}

/// Hyperparameters for a fine-tuning job.
public struct Hyperparameters: Codable, Sendable {
    public let nEpochs: HyperparameterValue?
    public let batchSize: HyperparameterValue?
    public let learningRateMultiplier: HyperparameterValue?
}

/// A hyperparameter value — can be "auto" or a specific number.
public enum HyperparameterValue: Codable, Sendable {
    case auto
    case int(Int)
    case double(Double)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self), str == "auto" {
            self = .auto
        } else if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let doubleVal = try? container.decode(Double.self) {
            self = .double(doubleVal)
        } else {
            self = .auto
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .auto: try container.encode("auto")
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        }
    }
}

/// An error from a fine-tuning job.
public struct FineTuningJobError: Codable, Sendable {
    public let code: String
    public let message: String
    public let param: String?
}

/// An event from a fine-tuning job.
public struct FineTuningEvent: Codable, Sendable {
    public let id: String
    public let object: String
    public let createdAt: Int
    public let level: String
    public let message: String
    public let type: String?
}

/// A fine-tuning checkpoint.
public struct FineTuningCheckpoint: Codable, Sendable {
    public let id: String
    public let object: String
    public let createdAt: Int
    public let fineTunedModelCheckpoint: String
    public let fineTuningJobId: String
    public let metrics: FineTuningCheckpointMetrics?
    public let stepNumber: Int
}

/// Metrics for a fine-tuning checkpoint.
public struct FineTuningCheckpointMetrics: Codable, Sendable {
    public let step: Int?
    public let trainLoss: Double?
    public let trainMeanTokenAccuracy: Double?
    public let validLoss: Double?
    public let validMeanTokenAccuracy: Double?
    public let fullValidLoss: Double?
    public let fullValidMeanTokenAccuracy: Double?
}

/// Parameters for creating a fine-tuning job.
struct FineTuningJobCreateParams: Encodable, Sendable {
    let model: String
    let trainingFile: String
    let validationFile: String?
    let hyperparameters: HyperparametersParam?
    let suffix: String?
    let seed: Int?
}

/// Hyperparameter settings for the create request.
public struct HyperparametersParam: Encodable, Sendable {
    public let nEpochs: HyperparameterValue?
    public let batchSize: HyperparameterValue?
    public let learningRateMultiplier: HyperparameterValue?

    public init(
        nEpochs: HyperparameterValue? = nil,
        batchSize: HyperparameterValue? = nil,
        learningRateMultiplier: HyperparameterValue? = nil
    ) {
        self.nEpochs = nEpochs
        self.batchSize = batchSize
        self.learningRateMultiplier = learningRateMultiplier
    }
}
