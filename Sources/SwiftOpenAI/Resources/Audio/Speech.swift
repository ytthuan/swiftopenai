import Foundation

/// Generates audio from text.
public struct Speech: Sendable {
    private let client: HTTPClient

    init(client: HTTPClient) { self.client = client }

    /// Generates audio from the input text.
    ///
    /// - Parameters:
    ///   - model: The TTS model ("tts-1" or "tts-1-hd").
    ///   - input: The text to generate audio for (max 4096 chars).
    ///   - voice: The voice to use ("alloy", "echo", "fable", "onyx", "nova", "shimmer").
    ///   - responseFormat: Audio format ("mp3", "opus", "aac", "flac", "wav", "pcm").
    ///   - speed: Speed of the generated audio (0.25–4.0).
    /// - Returns: The raw audio data.
    public func create(
        model: String,
        input: String,
        voice: String,
        responseFormat: String? = nil,
        speed: Double? = nil
    ) async throws -> Data {
        let body = SpeechCreateParams(
            model: model,
            input: input,
            voice: voice,
            responseFormat: responseFormat,
            speed: speed
        )
        let request = try client.buildRequest(path: "audio/speech", method: "POST", body: body)
        return try await client.performRaw(request: request)
    }
}
