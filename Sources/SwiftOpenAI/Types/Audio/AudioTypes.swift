import Foundation

/// A transcription response.
public struct Transcription: Codable, Sendable {
    /// The transcribed text.
    public let text: String
}

/// A translation response.
public struct Translation: Codable, Sendable {
    /// The translated text.
    public let text: String
}

/// Parameters for speech generation.
struct SpeechCreateParams: Encodable, Sendable {
    let model: String
    let input: String
    let voice: String
    let responseFormat: String?
    let speed: Double?
}
