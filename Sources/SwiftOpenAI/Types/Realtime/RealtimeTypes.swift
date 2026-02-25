import Foundation

// MARK: - Session Configuration

/// Configuration for a Realtime API session.
public struct RealtimeSessionConfig: Codable, Sendable {
    /// Session type: "realtime" for speech-to-speech, "transcription" for audio transcription.
    public var type: String?
    /// The model to use (e.g., "gpt-realtime", "gpt-4o-realtime-preview").
    public var model: String?
    /// Instructions for the model.
    public var instructions: String?
    /// Input modalities (e.g., ["text", "audio"]).
    public var modalities: [String]?
    /// Audio configuration.
    public var audio: RealtimeAudioConfig?
    /// Tools (functions) available to the model.
    public var tools: [RealtimeTool]?
    /// Tool choice strategy.
    public var toolChoice: String?
    /// Temperature for sampling.
    public var temperature: Double?
    /// Maximum output tokens.
    public var maxOutputTokens: RealtimeMaxTokens?
    /// Turn detection configuration.
    public var turnDetection: RealtimeTurnDetection?
    
    enum CodingKeys: String, CodingKey {
        case type, model, instructions, modalities, audio, tools
        case toolChoice, temperature, turnDetection
        case maxOutputTokens = "maxResponseOutputTokens"
    }
    
    public init(
        type: String? = "realtime",
        model: String? = nil,
        instructions: String? = nil,
        modalities: [String]? = nil,
        audio: RealtimeAudioConfig? = nil,
        tools: [RealtimeTool]? = nil,
        toolChoice: String? = nil,
        temperature: Double? = nil,
        maxOutputTokens: RealtimeMaxTokens? = nil,
        turnDetection: RealtimeTurnDetection? = nil
    ) {
        self.type = type
        self.model = model
        self.instructions = instructions
        self.modalities = modalities
        self.audio = audio
        self.tools = tools
        self.toolChoice = toolChoice
        self.temperature = temperature
        self.maxOutputTokens = maxOutputTokens
        self.turnDetection = turnDetection
    }
}

/// Audio configuration for Realtime sessions.
public struct RealtimeAudioConfig: Codable, Sendable {
    /// Input audio configuration.
    public var input: RealtimeAudioInput?
    /// Output audio configuration.
    public var output: RealtimeAudioOutput?
    
    public init(input: RealtimeAudioInput? = nil, output: RealtimeAudioOutput? = nil) {
        self.input = input
        self.output = output
    }
}

/// Input audio configuration.
public struct RealtimeAudioInput: Codable, Sendable {
    /// Audio format (e.g., "pcm16", "g711_ulaw", "g711_alaw").
    public var format: String?
    
    public init(format: String? = nil) {
        self.format = format
    }
}

/// Output audio configuration.
public struct RealtimeAudioOutput: Codable, Sendable {
    /// Audio format (e.g., "pcm16", "g711_ulaw", "g711_alaw").
    public var format: String?
    /// Voice to use (e.g., "alloy", "echo", "shimmer", "marin").
    public var voice: String?
    
    public init(format: String? = nil, voice: String? = nil) {
        self.format = format
        self.voice = voice
    }
}

/// Maximum output tokens — can be an integer or "inf".
public enum RealtimeMaxTokens: Codable, Sendable {
    case count(Int)
    case infinite
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) {
            self = .count(value)
        } else if let str = try? container.decode(String.self), str == "inf" {
            self = .infinite
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Expected Int or \"inf\""))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .count(let n): try container.encode(n)
        case .infinite: try container.encode("inf")
        }
    }
}

/// Turn detection configuration.
public struct RealtimeTurnDetection: Codable, Sendable {
    /// Type of turn detection (e.g., "server_vad", "semantic_vad").
    public var type: String?
    /// Activation threshold (0.0-1.0).
    public var threshold: Double?
    /// Prefix padding in milliseconds.
    public var prefixPaddingMs: Int?
    /// Silence duration in milliseconds.
    public var silenceDurationMs: Int?
    /// Whether to create a response on turn end.
    public var createResponse: Bool?
    
    // Standard snake_case keys are handled by convertFromSnakeCase/convertToSnakeCase
    
    public init(
        type: String? = nil,
        threshold: Double? = nil,
        prefixPaddingMs: Int? = nil,
        silenceDurationMs: Int? = nil,
        createResponse: Bool? = nil
    ) {
        self.type = type
        self.threshold = threshold
        self.prefixPaddingMs = prefixPaddingMs
        self.silenceDurationMs = silenceDurationMs
        self.createResponse = createResponse
    }
}

/// A tool available in the Realtime session.
public struct RealtimeTool: Codable, Sendable {
    /// Tool type, always "function".
    public var type: String
    /// Function name.
    public var name: String
    /// Function description.
    public var description: String?
    /// JSON Schema for function parameters.
    public var parameters: AnyCodable?
    
    public init(type: String = "function", name: String, description: String? = nil, parameters: AnyCodable? = nil) {
        self.type = type
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

// MARK: - Conversation Items

/// A conversation item in the Realtime API.
public struct RealtimeConversationItem: Codable, Sendable {
    /// Unique item ID.
    public var id: String?
    /// Object type.
    public var object: String?
    /// Item type: "message", "function_call", "function_call_output".
    public var type: String
    /// Item status.
    public var status: String?
    /// Role for message items: "user", "assistant", "system".
    public var role: String?
    /// Content parts for message items.
    public var content: [RealtimeContentPart]?
    /// Call ID for function call items.
    public var callId: String?
    /// Function name for function call items.
    public var name: String?
    /// Function arguments (JSON string) for function call items.
    public var arguments: String?
    /// Output for function_call_output items.
    public var output: String?
    
    // Standard snake_case keys (call_id → callId) handled by convertFromSnakeCase/convertToSnakeCase
    
    public init(
        id: String? = nil,
        type: String,
        role: String? = nil,
        content: [RealtimeContentPart]? = nil,
        callId: String? = nil,
        name: String? = nil,
        arguments: String? = nil,
        output: String? = nil
    ) {
        self.id = id
        self.type = type
        self.role = role
        self.content = content
        self.callId = callId
        self.name = name
        self.arguments = arguments
        self.output = output
    }
}

/// A content part within a conversation item.
public struct RealtimeContentPart: Codable, Sendable {
    /// Content type: "input_text", "input_audio", "output_text", "output_audio".
    public var type: String
    /// Text content.
    public var text: String?
    /// Base64-encoded audio data.
    public var audio: String?
    /// Transcript of audio.
    public var transcript: String?
    
    public init(type: String, text: String? = nil, audio: String? = nil, transcript: String? = nil) {
        self.type = type
        self.text = text
        self.audio = audio
        self.transcript = transcript
    }
}

// MARK: - Session Object (returned by server)

/// A Realtime session object returned by the server.
public struct RealtimeSession: Codable, Sendable {
    public let id: String?
    public let object: String?
    public let model: String?
    public let modalities: [String]?
    public let instructions: String?
    public let voice: String?
    public let turnDetection: RealtimeTurnDetection?
    public let tools: [RealtimeTool]?
    public let temperature: Double?
    public let maxOutputTokens: RealtimeMaxTokens?
    
    enum CodingKeys: String, CodingKey {
        case id, object, model, modalities, instructions, voice
        case turnDetection, tools, temperature
        case maxOutputTokens = "maxResponseOutputTokens"
    }
}

// MARK: - Response Configuration

/// Configuration for creating a response in the Realtime session.
public struct RealtimeResponseConfig: Codable, Sendable {
    /// Modalities for this response.
    public var modalities: [String]?
    /// Instructions override for this response.
    public var instructions: String?
    /// Tools for this response.
    public var tools: [RealtimeTool]?
    /// Temperature override.
    public var temperature: Double?
    /// Max output tokens override.
    public var maxOutputTokens: RealtimeMaxTokens?
    
    enum CodingKeys: String, CodingKey {
        case modalities, instructions, tools, temperature
        case maxOutputTokens = "maxResponseOutputTokens"
    }
    
    public init(
        modalities: [String]? = nil,
        instructions: String? = nil,
        tools: [RealtimeTool]? = nil,
        temperature: Double? = nil,
        maxOutputTokens: RealtimeMaxTokens? = nil
    ) {
        self.modalities = modalities
        self.instructions = instructions
        self.tools = tools
        self.temperature = temperature
        self.maxOutputTokens = maxOutputTokens
    }
}

// MARK: - Rate Limit Info

/// Rate limit information from a Realtime session.
public struct RealtimeRateLimit: Codable, Sendable {
    public let name: String?
    public let limit: Int?
    public let remaining: Int?
    public let resetSeconds: Double?
}

// MARK: - Realtime Usage

/// Token usage in a Realtime response.
public struct RealtimeUsage: Codable, Sendable {
    public let totalTokens: Int?
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let inputTokenDetails: RealtimeTokenDetails?
    public let outputTokenDetails: RealtimeTokenDetails?
}

/// Detailed token breakdown.
public struct RealtimeTokenDetails: Codable, Sendable {
    public let cachedTokens: Int?
    public let textTokens: Int?
    public let audioTokens: Int?
}

// MARK: - Realtime Response Object

/// A response object from the Realtime API.
public struct RealtimeResponse: Codable, Sendable {
    public let id: String?
    public let object: String?
    public let status: String?
    public let output: [RealtimeConversationItem]?
    public let usage: RealtimeUsage?
}
