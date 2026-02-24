import Foundation

/// Transcribes audio into text.
public struct Transcriptions: Sendable {
    private let client: HTTPClient

    init(client: HTTPClient) { self.client = client }

    /// Transcribes audio into the input language.
    ///
    /// - Parameters:
    ///   - file: The audio file data.
    ///   - filename: The audio file name (e.g. "audio.mp3").
    ///   - model: ID of the model to use (e.g. "whisper-1").
    ///   - language: The language of the input audio (ISO-639-1).
    ///   - prompt: Optional text to guide the model's style.
    ///   - responseFormat: The format of the output ("json", "text", "srt", "verbose_json", "vtt").
    ///   - temperature: Sampling temperature (0-1).
    /// - Returns: A ``Transcription`` containing the transcribed text.
    public func create(
        file: Data,
        filename: String,
        model: String,
        language: String? = nil,
        prompt: String? = nil,
        responseFormat: String? = nil,
        temperature: Double? = nil
    ) async throws -> Transcription {
        var formData = MultipartFormData()
        formData.addFile(name: "file", filename: filename, mimeType: "audio/mpeg", data: file)
        formData.addField(name: "model", value: model)
        if let language { formData.addField(name: "language", value: language) }
        if let prompt { formData.addField(name: "prompt", value: prompt) }
        if let responseFormat { formData.addField(name: "response_format", value: responseFormat) }
        if let temperature { formData.addField(name: "temperature", value: String(temperature)) }
        return try await client.postMultipart(path: "audio/transcriptions", formData: formData)
    }
}
