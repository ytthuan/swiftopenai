import Foundation

/// The result of evaluating a set of Decisions questions.
public struct Decision: Codable, Sendable, Equatable {
    /// The model used to evaluate the request.
    public let model: String
    /// Answers in question order, including any per-question refusals.
    public let answers: [DecisionAnswer]
    /// Token usage, including cache reads and writes.
    public let usage: DecisionUsage

    /// Creates a Decisions result.
    public init(model: String, answers: [DecisionAnswer], usage: DecisionUsage) {
        self.model = model
        self.answers = answers
        self.usage = usage
    }
}

/// The probability assigned to a particular string or Boolean choice.
public struct DecisionChoiceProbability: Codable, Sendable, Equatable {
    /// The supplied choice value, retaining its JSON type.
    public let value: DecisionChoiceValue
    /// The estimated probability assigned to the value.
    public let probability: Double

    /// Creates a choice-probability entry.
    public init(value: DecisionChoiceValue, probability: Double) {
        self.value = value
        self.probability = probability
    }
}

/// The probability assigned to a rubric level.
public struct DecisionScoreProbability: Codable, Sendable, Equatable {
    /// The supplied rubric label.
    public let label: String
    /// The zero-based index of the rubric level.
    public let value: Int
    /// The estimated probability assigned to the level.
    public let probability: Double

    /// Creates a rubric-level probability entry.
    public init(label: String, value: Int, probability: Double) {
        self.label = label
        self.value = value
        self.probability = probability
    }
}

/// One typed Decisions answer, a refusal, or a future answer representation.
public enum DecisionAnswer: Codable, Sendable, Equatable {
    /// The probability that a condition is true.
    case predicate(name: String?, probability: Double)
    /// The chosen value, confidence, and probability of each supplied option.
    case choice(name: String?, choice: DecisionChoiceValue, confidence: Double, probabilities: [DecisionChoiceProbability])
    /// A possibly fractional score, confidence, and probability of each rubric level.
    case score(name: String?, score: Double, confidence: Double, probabilities: [DecisionScoreProbability])
    /// The model declined to answer this question; other answers remain usable.
    case refusal(name: String?)
    /// An unrecognized answer type, retained as complete structured JSON.
    case other(JSONValue)

    /// The question name, or `nil` for an unnamed question.
    public var name: String? {
        switch self {
        case .predicate(let name, _), .choice(let name, _, _, _), .score(let name, _, _, _), .refusal(let name):
            return name
        case .other(.object(let fields)):
            if case .string(let name) = fields["name"] { return name }
            return nil
        case .other:
            return nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, name, probability, choice, confidence, probabilities, score
    }

    /// Decodes by answer type; malformed known types throw instead of becoming unknown answers.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "predicate":
            self = .predicate(
                name: try container.decodeIfPresent(String.self, forKey: .name),
                probability: try container.decode(Double.self, forKey: .probability)
            )
        case "choice":
            self = .choice(
                name: try container.decodeIfPresent(String.self, forKey: .name),
                choice: try container.decode(DecisionChoiceValue.self, forKey: .choice),
                confidence: try container.decode(Double.self, forKey: .confidence),
                probabilities: try container.decode([DecisionChoiceProbability].self, forKey: .probabilities)
            )
        case "score":
            self = .score(
                name: try container.decodeIfPresent(String.self, forKey: .name),
                score: try container.decode(Double.self, forKey: .score),
                confidence: try container.decode(Double.self, forKey: .confidence),
                probabilities: try container.decode([DecisionScoreProbability].self, forKey: .probabilities)
            )
        case "refusal":
            self = .refusal(name: try container.decodeIfPresent(String.self, forKey: .name))
        default:
            self = .other(try JSONValue(from: decoder))
        }
    }

    /// Encodes the answer discriminator and payload, retaining null question names.
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .predicate(let name, let probability):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encode("predicate", forKey: .type)
            try container.encode(probability, forKey: .probability)
        case .choice(let name, let choice, let confidence, let probabilities):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encode("choice", forKey: .type)
            try container.encode(choice, forKey: .choice)
            try container.encode(confidence, forKey: .confidence)
            try container.encode(probabilities, forKey: .probabilities)
        case .score(let name, let score, let confidence, let probabilities):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encode("score", forKey: .type)
            try container.encode(score, forKey: .score)
            try container.encode(confidence, forKey: .confidence)
            try container.encode(probabilities, forKey: .probabilities)
        case .refusal(let name):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encode("refusal", forKey: .type)
        case .other(let value):
            try value.encode(to: encoder)
        }
    }
}

/// Complete token accounting for a Decisions request.
public struct DecisionUsage: Codable, Sendable, Equatable {
    /// Total input tokens, including cache reads and writes.
    public let inputTokens: Int
    /// Input cache-read and cache-write counts, already included in input tokens.
    public let inputTokensDetails: InputTokensDetails
    /// Output tokens reported by the service.
    public let outputTokens: Int
    /// Reasoning-token details for the output.
    public let outputTokensDetails: OutputTokensDetails
    /// Total input and output tokens.
    public let totalTokens: Int

    /// Input prompt-cache accounting.
    public struct InputTokensDetails: Codable, Sendable, Equatable {
        /// Input tokens retrieved from the prompt cache.
        public let cachedTokens: Int
        /// Input tokens written to the prompt cache.
        public let cacheWriteTokens: Int

        /// Creates input prompt-cache accounting.
        public init(cachedTokens: Int, cacheWriteTokens: Int) {
            self.cachedTokens = cachedTokens
            self.cacheWriteTokens = cacheWriteTokens
        }
    }

    /// Output reasoning-token accounting.
    public struct OutputTokensDetails: Codable, Sendable, Equatable {
        /// Output tokens used for reasoning.
        public let reasoningTokens: Int

        /// Creates output reasoning-token accounting.
        public init(reasoningTokens: Int) {
            self.reasoningTokens = reasoningTokens
        }
    }

    /// Creates complete Decisions token accounting.
    public init(
        inputTokens: Int,
        inputTokensDetails: InputTokensDetails,
        outputTokens: Int,
        outputTokensDetails: OutputTokensDetails,
        totalTokens: Int
    ) {
        self.inputTokens = inputTokens
        self.inputTokensDetails = inputTokensDetails
        self.outputTokens = outputTokens
        self.outputTokensDetails = outputTokensDetails
        self.totalTokens = totalTokens
    }
}
