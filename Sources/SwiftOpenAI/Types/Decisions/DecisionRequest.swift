import Foundation

/// A choice value whose JSON string and Boolean representations remain distinct.
public enum DecisionChoiceValue: Codable, Sendable, Equatable, Hashable {
    /// A string category.
    case string(String)
    /// A Boolean category, distinct from the strings `"true"` and `"false"`.
    case bool(Bool)

    /// Decodes a string or Boolean choice, rejecting other JSON types.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected a string or Boolean decision choice")
        }
    }

    /// Encodes the choice using its original JSON type.
    public func encode(to encoder: Encoder) throws {
        try jsonValue.encode(to: encoder)
    }

    fileprivate var jsonValue: JSONValue {
        switch self {
        case .string(let value): return .string(value)
        case .bool(let value): return .bool(value)
        }
    }
}

extension DecisionChoiceValue: ExpressibleByStringLiteral {
    /// Creates a string choice from a literal.
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension DecisionChoiceValue: ExpressibleByBooleanLiteral {
    /// Creates a Boolean choice from a literal.
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

/// One allowed category in a choice question.
public struct DecisionChoiceOption: Codable, Sendable, Equatable {
    /// The unique string or Boolean value for this category.
    public let value: DecisionChoiceValue
    /// Optional criteria explaining when this category applies.
    public let description: String?

    /// Creates a choice option with optional selection criteria.
    public init(value: DecisionChoiceValue, description: String? = nil) {
        self.value = value
        self.description = description
    }

    fileprivate var jsonValue: JSONValue {
        var fields: [String: JSONValue] = ["value": value.jsonValue]
        if let description { fields["description"] = .string(description) }
        return .object(fields)
    }
}

/// One rubric level in a score question, ordered from lowest to highest.
public struct DecisionScoreLevel: Codable, Sendable, Equatable {
    /// The name of this level.
    public let label: String
    /// Optional criteria explaining this level.
    public let description: String?

    /// Creates a rubric level with optional criteria.
    public init(label: String, description: String? = nil) {
        self.label = label
        self.description = description
    }

    fileprivate var jsonValue: JSONValue {
        var fields: [String: JSONValue] = ["label": .string(label)]
        if let description { fields["description"] = .string(description) }
        return .object(fields)
    }
}

/// A question's instructions as text or a nonempty array of question-specific parts.
public struct DecisionInstructions: Codable, Sendable, Equatable {
    /// The complete wire representation of the instructions.
    public let jsonValue: JSONValue

    /// Creates instructions from a caller-supplied wire representation.
    public init(jsonValue: JSONValue) {
        self.jsonValue = jsonValue
    }

    /// Creates plain-text instructions.
    public static func text(_ text: String) -> Self {
        Self(jsonValue: .string(text))
    }

    /// Creates multimodal instructions without a message wrapper or cache breakpoints.
    public static func parts(_ parts: [DecisionQuestionInputPart]) -> Self {
        Self(jsonValue: .array(parts.map(\.jsonValue)))
    }

    /// Decodes the complete instructions representation.
    public init(from decoder: Decoder) throws {
        self.jsonValue = try JSONValue(from: decoder)
    }

    /// Encodes the complete instructions representation.
    public func encode(to encoder: Encoder) throws {
        try jsonValue.encode(to: encoder)
    }
}

/// A predicate, fixed-choice, or ordered-rubric question about shared evidence.
public struct DecisionQuestion: Codable, Sendable, Equatable {
    /// The complete JSON representation of the question.
    public let jsonValue: JSONValue

    /// Creates a question from a caller-supplied wire representation.
    public init(jsonValue: JSONValue) {
        self.jsonValue = jsonValue
    }

    /// Asks for the probability that the instructed condition is true.
    public static func predicate(instructions: DecisionInstructions, name: String? = nil) -> Self {
        question(type: "predicate", instructions: instructions, name: name)
    }

    /// Asks the model to select from 2–255 distinct string or Boolean values.
    public static func choice(instructions: DecisionInstructions, choices: [DecisionChoiceOption], name: String? = nil) -> Self {
        question(type: "choice", instructions: instructions, name: name, fields: ["choices": .array(choices.map(\.jsonValue))])
    }

    /// Asks for a probability-weighted score across 2–10 ordered rubric levels.
    public static func score(instructions: DecisionInstructions, levels: [DecisionScoreLevel], name: String? = nil) -> Self {
        question(type: "score", instructions: instructions, name: name, fields: ["levels": .array(levels.map(\.jsonValue))])
    }

    /// Decodes the complete question representation.
    public init(from decoder: Decoder) throws {
        self.jsonValue = try JSONValue(from: decoder)
    }

    /// Encodes the complete question representation.
    public func encode(to encoder: Encoder) throws {
        try jsonValue.encode(to: encoder)
    }

    private static func question(
        type: String, instructions: DecisionInstructions, name: String?, fields: [String: JSONValue] = [:]
    ) -> Self {
        var fields = fields
        fields["type"] = .string(type)
        fields["instructions"] = instructions.jsonValue
        if let name { fields["name"] = .string(name) }
        return Self(jsonValue: .object(fields))
    }
}

/// Parameters for `POST /decisions`.
///
/// The service validates model availability and request limits, including the
/// supported range of 1–400 questions. Unset optional settings are omitted.
public struct DecisionCreateRequest: Encodable, Sendable {
    /// The model ID; currently the service supports `gpt-6-luna`.
    public let model: String
    /// Shared evidence evaluated for every question.
    public let input: DecisionInput
    /// Questions to evaluate, with answers returned in the same order.
    public let questions: [DecisionQuestion]
    /// Optional caller-provided key partitioning prompt-cache reuse.
    public let promptCacheKey: String?
    /// Optional prompt-cache mode and lifetime settings.
    public let promptCacheOptions: PromptCacheOptions?
    /// Optional opaque end-user identifier for safety monitoring.
    public let safetyIdentifier: String?

    /// Creates a Decisions request with optional caching and safety settings.
    public init(
        model: String,
        input: DecisionInput,
        questions: [DecisionQuestion],
        promptCacheKey: String? = nil,
        promptCacheOptions: PromptCacheOptions? = nil,
        safetyIdentifier: String? = nil
    ) {
        self.model = model
        self.input = input
        self.questions = questions
        self.promptCacheKey = promptCacheKey
        self.promptCacheOptions = promptCacheOptions
        self.safetyIdentifier = safetyIdentifier
    }
}
