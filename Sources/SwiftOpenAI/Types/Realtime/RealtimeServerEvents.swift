import Foundation

/// A server event received from the Realtime API.
///
/// Uses a type-erased approach — the `type` field determines which optional
/// properties are populated for each event.
public struct RealtimeServerEvent: Codable, Sendable {
    /// The event type (e.g., "session.created", "response.output_text.delta").
    public let type: String
    /// Server-assigned event ID.
    public let eventId: String?
    
    // MARK: - Session Events
    public let session: RealtimeSession?
    
    // MARK: - Conversation Item Events
    public let item: RealtimeConversationItem?
    public let previousItemId: String?
    
    // MARK: - Response Events
    public let response: RealtimeResponse?
    public let responseId: String?
    public let itemId: String?
    public let outputIndex: Int?
    public let contentIndex: Int?
    
    // MARK: - Delta Events
    /// Text delta for response.output_text.delta.
    public let delta: String?
    /// Audio delta (base64) for response.output_audio.delta.
    public let audio: String?
    /// Function call arguments delta.
    public let arguments: String?
    /// Transcript text.
    public let transcript: String?
    /// Name (e.g., function name).
    public let name: String?
    /// Call ID for function calls.
    public let callId: String?
    
    // MARK: - Audio Buffer Events
    /// Audio end timestamp in ms.
    public let audioEndMs: Int?
    
    // MARK: - Error Events
    public let error: RealtimeError?
    
    // MARK: - Rate Limit Events
    public let rateLimits: [RealtimeRateLimit]?
    
    // MARK: - Usage
    public let usage: RealtimeUsage?
    
    // MARK: - Text content (for done events)
    public let text: String?
}

/// A Realtime API error.
public struct RealtimeError: Codable, Sendable {
    public let type: String?
    public let code: String?
    public let message: String?
    public let param: String?
}
