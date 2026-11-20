import Foundation

/// The result of evaluating named questions through Microsoft System One.
public struct SystemOneResponse: Codable, Sendable, Equatable {
    /// The underlying model reported by the service (for example `"microsoft-decision-1.1"`).
    public let model: String
    /// Typed answers keyed by the question names supplied in the request.
    public let answers: [String: SystemOneAnswer]
    /// Token usage reported by the service.
    public let usage: SystemOneUsage

    /// Creates a System One response.
    public init(model: String, answers: [String: SystemOneAnswer], usage: SystemOneUsage) {
        self.model = model
        self.answers = answers
        self.usage = usage
    }
}

/// One typed Microsoft System One answer or a future answer representation.
public enum SystemOneAnswer: Codable, Sendable, Equatable {
    /// The probability (`0...1`) that the instructed condition is true (wire field `"noul"`).
    case noul(probability: Double)
    /// The selected choice label, confidence, and probability distribution for all options.
    case choice(choice: String, confidence: Double, probabilities: [String: Double])
    /// The probability-weighted score, confidence, per-level probabilities, and optional level legend.
    case score(score: Double, confidence: Double, probabilities: [String: Double], legend: [String: String]?)
    /// An unrecognized answer type, retained as complete structured JSON.
    case other(JSONValue)

    private enum CodingKeys: String, CodingKey {
        case type, noul, choice, confidence, probabilities, score, legend
    }

    /// Decodes by answer type; malformed known types throw instead of becoming unknown answers.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "noul":
            self = .noul(probability: try container.decode(Double.self, forKey: .noul))
        case "choice":
            self = .choice(
                choice: try container.decode(String.self, forKey: .choice),
                confidence: try container.decode(Double.self, forKey: .confidence),
                probabilities: try container.decode([String: Double].self, forKey: .probabilities)
            )
        case "score":
            self = .score(
                score: try container.decode(Double.self, forKey: .score),
                confidence: try container.decode(Double.self, forKey: .confidence),
                probabilities: try container.decode([String: Double].self, forKey: .probabilities),
                legend: try container.decodeIfPresent([String: String].self, forKey: .legend)
            )
        default:
            self = .other(try JSONValue(from: decoder))
        }
    }

    /// Encodes the answer discriminator and payload.
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .noul(let probability):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("noul", forKey: .type)
            try container.encode(probability, forKey: .noul)
        case .choice(let choice, let confidence, let probabilities):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("choice", forKey: .type)
            try container.encode(choice, forKey: .choice)
            try container.encode(confidence, forKey: .confidence)
            try container.encode(probabilities, forKey: .probabilities)
        case .score(let score, let confidence, let probabilities, let legend):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("score", forKey: .type)
            try container.encode(score, forKey: .score)
            try container.encode(confidence, forKey: .confidence)
            try container.encode(probabilities, forKey: .probabilities)
            try container.encodeIfPresent(legend, forKey: .legend)
        case .other(let value):
            try value.encode(to: encoder)
        }
    }
}

/// Token usage reported for a Microsoft System One request.
public struct SystemOneUsage: Codable, Sendable, Equatable {
    /// Input tokens processed by the service.
    public let inputTokens: Int
    /// Output tokens produced by the service.
    public let outputTokens: Int
    /// Optional total token count when reported by the service or gateway.
    public let totalTokens: Int?

    /// Creates System One token usage.
    public init(inputTokens: Int, outputTokens: Int, totalTokens: Int? = nil) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
    }
}
