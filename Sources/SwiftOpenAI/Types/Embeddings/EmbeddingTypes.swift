import Foundation

/// Input for the embeddings endpoint.
public struct CreateEmbeddingRequest: Encodable, Sendable {
    /// Input text to embed, encoded as a string or array of strings.
    public let input: EmbeddingInput
    /// ID of the model to use.
    public let model: String
    /// The number of dimensions the resulting output embeddings should have (text-embedding-3 and later).
    public let dimensions: Int?
    /// The format to return the embeddings in ("float" or "base64").
    public let encodingFormat: String?
    /// A unique identifier representing your end-user.
    public let user: String?

    public init(
        input: EmbeddingInput,
        model: String,
        dimensions: Int? = nil,
        encodingFormat: String? = nil,
        user: String? = nil
    ) {
        self.input = input
        self.model = model
        self.dimensions = dimensions
        self.encodingFormat = encodingFormat
        self.user = user
    }
}

/// The input to embed — can be a single string or array of strings.
public enum EmbeddingInput: Encodable, Sendable {
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

/// Response from the embeddings endpoint.
public struct CreateEmbeddingResponse: Codable, Sendable {
    /// The object type, always "list".
    public let object: String
    /// The list of embeddings.
    public let data: [Embedding]
    /// The model used to generate the embeddings.
    public let model: String
    /// Token usage for the request.
    public let usage: EmbeddingUsage
}

/// Represents an embedding value that can be either a float array or base64 string.
public enum EmbeddingValue: Codable, Sendable {
    case floats([Double])
    case base64(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let arr = try? container.decode([Double].self) {
            self = .floats(arr)
        } else if let str = try? container.decode(String.self) {
            self = .base64(str)
        } else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Expected [Double] or String for embedding"
            ))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .floats(let arr): try container.encode(arr)
        case .base64(let str): try container.encode(str)
        }
    }
}

/// A single embedding vector.
public struct Embedding: Codable, Sendable {
    /// The object type, always "embedding".
    public let object: String
    /// The embedding vector (float array or base64 string).
    public let embedding: EmbeddingValue
    /// The index of the embedding in the list of embeddings.
    public let index: Int
}

/// Token usage for an embeddings request.
public struct EmbeddingUsage: Codable, Sendable {
    /// The number of tokens in the input.
    public let promptTokens: Int
    /// The total number of tokens used.
    public let totalTokens: Int
}
