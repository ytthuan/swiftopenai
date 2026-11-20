import Foundation

/// Shared state evaluated by a Microsoft System One decision request: plain text or JSON.
public struct SystemOneState: Codable, Sendable, Equatable {
    /// The complete wire representation of the state.
    public let jsonValue: JSONValue

    /// Creates a state value from a caller-supplied wire representation.
    public init(jsonValue: JSONValue) {
        self.jsonValue = jsonValue
    }

    /// Creates plain-text state shared by all questions.
    public static func text(_ text: String) -> Self {
        Self(jsonValue: .string(text))
    }

    /// Creates structured JSON state shared by all questions.
    public static func json(_ value: JSONValue) -> Self {
        Self(jsonValue: value)
    }

    /// Decodes the complete state representation.
    public init(from decoder: Decoder) throws {
        self.jsonValue = try JSONValue(from: decoder)
    }

    /// Encodes the state without changing caller-supplied JSON keys.
    public func encode(to encoder: Encoder) throws {
        try jsonValue.encode(to: encoder)
    }
}

/// An uploaded asset referenced from System One state, instructions, or choice criteria.
public struct SystemOneAsset: Codable, Sendable, Equatable {
    /// The complete wire representation of the asset.
    public let jsonValue: JSONValue

    /// Creates an asset from a caller-supplied wire representation.
    public init(jsonValue: JSONValue) {
        self.jsonValue = jsonValue
    }

    /// Creates a base64-encoded image asset referenced as `image:<name>` in the request.
    ///
    /// - Parameters:
    ///   - format: Image format string (for example `"png"` or `"jpeg"`).
    ///   - dataBase64: Base64-encoded image bytes.
    public static func image(format: String, dataBase64: String) -> Self {
        Self(jsonValue: .object([
            "type": .string("image"),
            "format": .string(format),
            "data_base64": .string(dataBase64),
        ]))
    }

    /// Decodes the complete asset representation.
    public init(from decoder: Decoder) throws {
        self.jsonValue = try JSONValue(from: decoder)
    }

    /// Encodes the complete asset representation.
    public func encode(to encoder: Encoder) throws {
        try jsonValue.encode(to: encoder)
    }
}

/// Optional true/false boundary criteria for a `noul` question.
public struct SystemOneNoulCriteria: Codable, Sendable, Equatable {
    /// Criteria describing when the condition should evaluate as true.
    public let trueDescription: String
    /// Criteria describing when the condition should evaluate as false.
    public let falseDescription: String

    /// Creates true and false boundary criteria for a `noul` question.
    ///
    /// - Parameters:
    ///   - trueDescription: Condition describing when the answer is true.
    ///   - falseDescription: Condition describing when the answer is false.
    public init(true trueDescription: String, false falseDescription: String) {
        self.trueDescription = trueDescription
        self.falseDescription = falseDescription
    }

    private enum CodingKeys: String, CodingKey {
        case trueDescription = "true"
        case falseDescription = "false"
    }

    fileprivate var jsonValue: JSONValue {
        .object([
            "true": .string(trueDescription),
            "false": .string(falseDescription),
        ])
    }
}

/// A `noul`, `choice`, or `score` question for Microsoft System One (`Decision-1.1`).
public struct SystemOneQuestion: Codable, Sendable, Equatable {
    /// The complete wire representation of the question.
    public let jsonValue: JSONValue

    /// Creates a question from a caller-supplied wire representation.
    public init(jsonValue: JSONValue) {
        self.jsonValue = jsonValue
    }

    /// Asks for a probability (`0...1`) that the instructed yes/no condition is true.
    ///
    /// - Parameters:
    ///   - instructions: Question instructions evaluated against the shared state.
    ///   - criteria: Optional true/false descriptions clarifying borderline cases.
    public static func noul(
        instructions: String,
        criteria: SystemOneNoulCriteria? = nil
    ) -> Self {
        var fields: [String: JSONValue] = [
            "type": .string("noul"),
            "instructions": .string(instructions),
        ]
        if let criteria {
            fields["criteria"] = criteria.jsonValue
        }
        return Self(jsonValue: .object(fields))
    }

    /// Asks the model to select one option from a keyed dictionary of labels and descriptions.
    ///
    /// - Parameters:
    ///   - instructions: Question instructions evaluated against the shared state.
    ///   - criteria: Map of option label to its selection description.
    public static func choice(
        instructions: String,
        criteria: [String: String]
    ) -> Self {
        let encodedCriteria = criteria.mapValues(JSONValue.string)
        return Self(jsonValue: .object([
            "type": .string("choice"),
            "instructions": .string(instructions),
            "criteria": .object(encodedCriteria),
        ]))
    }

    /// Asks for a probability-weighted score across ordered rubric levels (lowest to highest).
    ///
    /// - Parameters:
    ///   - instructions: Question instructions evaluated against the shared state.
    ///   - criteria: Ordered level labels from lowest (`0`) to highest.
    public static func score(
        instructions: String,
        criteria: [String]
    ) -> Self {
        return Self(jsonValue: .object([
            "type": .string("score"),
            "instructions": .string(instructions),
            "criteria": .array(criteria.map(JSONValue.string)),
        ]))
    }

    /// Decodes the complete question representation.
    public init(from decoder: Decoder) throws {
        self.jsonValue = try JSONValue(from: decoder)
    }

    /// Encodes the complete question representation.
    public func encode(to encoder: Encoder) throws {
        try jsonValue.encode(to: encoder)
    }
}

/// Parameters for `POST /providers/microsoft/v1/systemone`.
public struct SystemOneCreateRequest: Codable, Sendable, Equatable {
    /// The Azure AI Foundry deployment name (for example `"Decision-1.1"`).
    public let model: String
    /// Shared text or structured JSON state evaluated for every question.
    public let state: SystemOneState
    /// Named questions to evaluate; response answers are keyed by the same names.
    public let questions: [String: SystemOneQuestion]
    /// Optional uploaded assets (such as base64 images) referenced by name in `state` or questions.
    public let assets: [String: SystemOneAsset]?

    /// Creates a native Microsoft System One request.
    ///
    /// - Parameters:
    ///   - model: Azure AI Foundry deployment name (for example `"Decision-1.1"`).
    ///   - state: Shared plain-text or structured JSON state.
    ///   - questions: Named questions to evaluate against the shared state.
    ///   - assets: Optional named assets (such as images) referenced in `state` or questions.
    public init(
        model: String,
        state: SystemOneState,
        questions: [String: SystemOneQuestion],
        assets: [String: SystemOneAsset]? = nil
    ) {
        self.model = model
        self.state = state
        self.questions = questions
        self.assets = assets
    }
}
