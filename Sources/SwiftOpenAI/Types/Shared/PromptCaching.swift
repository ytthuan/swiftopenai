import Foundation

/// Controls automatic prompt-cache breakpoint creation.
public enum PromptCacheMode: Codable, Sendable, Equatable, Hashable {
    /// OpenAI creates one implicit breakpoint in addition to explicit breakpoints.
    case implicit
    /// Only explicitly marked breakpoints are used.
    case explicit
    /// A forward-compatible mode value.
    case other(String)

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "implicit": self = .implicit
        case "explicit": self = .explicit
        default: self = .other(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .implicit: try container.encode("implicit")
        case .explicit: try container.encode("explicit")
        case .other(let value): try container.encode(value)
        }
    }
}

/// The minimum lifetime for prompt-cache entries.
public enum PromptCacheTTL: Codable, Sendable, Equatable, Hashable {
    /// A minimum lifetime of 30 minutes.
    case m30
    /// A forward-compatible TTL value.
    case other(String)

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "30m": self = .m30
        default: self = .other(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .m30: try container.encode("30m")
        case .other(let value): try container.encode(value)
        }
    }
}

/// Prompt-caching options applied to a request.
public struct PromptCacheOptions: Codable, Sendable, Equatable {
    /// Whether implicit cache breakpoints are enabled.
    public let mode: PromptCacheMode?
    /// The minimum lifetime applied to every written breakpoint.
    public let ttl: PromptCacheTTL?

    /// Creates prompt-caching options.
    public init(mode: PromptCacheMode? = nil, ttl: PromptCacheTTL? = nil) {
        self.mode = mode
        self.ttl = ttl
    }
}

/// Prompt-caching options echoed by a Responses API response.
///
/// The service always returns both values when `prompt_cache_options` is present.
public struct ResponsePromptCacheOptions: Codable, Sendable, Equatable {
    /// The applied cache-breakpoint mode.
    public let mode: PromptCacheMode
    /// The applied minimum cache lifetime.
    public let ttl: PromptCacheTTL

    /// Creates response prompt-caching options.
    public init(mode: PromptCacheMode, ttl: PromptCacheTTL) {
        self.mode = mode
        self.ttl = ttl
    }
}

/// Marks the exact end of a reusable prompt prefix.
///
/// Its `mode` discriminator is fixed to `"explicit"` and cannot be customized.
public struct PromptCacheBreakpoint: Codable, Sendable, Equatable {
    /// The fixed breakpoint mode, always `"explicit"`.
    public var mode: String { "explicit" }

    /// Creates a prompt-cache breakpoint.
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case mode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let mode = try container.decode(String.self, forKey: .mode)
        guard mode == "explicit" else {
            throw DecodingError.dataCorruptedError(
                forKey: .mode,
                in: container,
                debugDescription: "Expected PromptCacheBreakpoint mode \"explicit\", but found \"\(mode)\"."
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("explicit", forKey: .mode)
    }
}
