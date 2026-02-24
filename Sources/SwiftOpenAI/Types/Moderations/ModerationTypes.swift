import Foundation

/// Request for the moderations endpoint.
public struct ModerationCreateRequest: Encodable, Sendable {
    /// The input text to classify.
    public let input: ModerationInput
    /// The content moderation model to use.
    public let model: String?

    public init(input: ModerationInput, model: String? = nil) {
        self.input = input
        self.model = model
    }
}

/// Input for moderation — a single string or array of strings.
public enum ModerationInput: Encodable, Sendable {
    case string(String)
    case strings([String])

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .strings(let values):
            try container.encode(values)
        }
    }
}

/// Response from the moderations endpoint.
public struct ModerationCreateResponse: Codable, Sendable {
    public let id: String
    public let model: String
    public let results: [Moderation]
}

/// A single moderation result.
public struct Moderation: Codable, Sendable {
    public let flagged: Bool
    public let categories: ModerationCategories
    public let categoryScores: ModerationCategoryScores
}

/// Moderation categories indicating which policies were violated.
public struct ModerationCategories: Codable, Sendable {
    public let hate: Bool
    public let hateThreatening: Bool
    public let harassment: Bool
    public let harassmentThreatening: Bool
    public let selfHarm: Bool
    public let selfHarmIntent: Bool
    public let selfHarmInstructions: Bool
    public let sexual: Bool
    public let sexualMinors: Bool
    public let violence: Bool
    public let violenceGraphic: Bool

    enum CodingKeys: String, CodingKey {
        case hate
        case hateThreatening = "hate/threatening"
        case harassment
        case harassmentThreatening = "harassment/threatening"
        case selfHarm = "self-harm"
        case selfHarmIntent = "self-harm/intent"
        case selfHarmInstructions = "self-harm/instructions"
        case sexual
        case sexualMinors = "sexual/minors"
        case violence
        case violenceGraphic = "violence/graphic"
    }
}

/// Moderation category confidence scores (0–1).
public struct ModerationCategoryScores: Codable, Sendable {
    public let hate: Double
    public let hateThreatening: Double
    public let harassment: Double
    public let harassmentThreatening: Double
    public let selfHarm: Double
    public let selfHarmIntent: Double
    public let selfHarmInstructions: Double
    public let sexual: Double
    public let sexualMinors: Double
    public let violence: Double
    public let violenceGraphic: Double

    enum CodingKeys: String, CodingKey {
        case hate
        case hateThreatening = "hate/threatening"
        case harassment
        case harassmentThreatening = "harassment/threatening"
        case selfHarm = "self-harm"
        case selfHarmIntent = "self-harm/intent"
        case selfHarmInstructions = "self-harm/instructions"
        case sexual
        case sexualMinors = "sexual/minors"
        case violence
        case violenceGraphic = "violence/graphic"
    }
}
