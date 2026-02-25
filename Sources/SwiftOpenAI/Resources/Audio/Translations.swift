import Foundation

/// Translates audio into English.
public struct Translations: Sendable {
    private let client: HTTPClient

    init(client: HTTPClient) { self.client = client }

    /// Translates audio into English.
    ///
    /// - Parameters:
    ///   - file: The audio file data.
    ///   - filename: The audio file name (e.g. "audio.mp3").
    ///   - model: ID of the model to use (e.g. "whisper-1").
    ///   - prompt: Optional text to guide the model's style.
    ///   - responseFormat: The format of the output ("json", "text", "srt", "verbose_json", "vtt").
    ///   - temperature: Sampling temperature (0-1).
    /// - Returns: A ``Translation`` containing the translated text.
    public func create(
        file: Data,
        filename: String,
        model: String,
        prompt: String? = nil,
        responseFormat: String? = nil,
        temperature: Double? = nil
    ) async throws -> Translation {
        var formData = MultipartFormData()
        formData.addFile(name: "file", filename: filename, mimeType: "audio/mpeg", data: file)
        formData.addField(name: "model", value: model)
        if let prompt { formData.addField(name: "prompt", value: prompt) }
        if let responseFormat { formData.addField(name: "response_format", value: responseFormat) }
        if let temperature { formData.addField(name: "temperature", value: String(temperature)) }
        
        let textFormats = ["text", "srt", "vtt"]
        if let responseFormat, textFormats.contains(responseFormat) {
            let rawData = try await client.postMultipartRaw(path: "audio/translations", formData: formData)
            let text = String(data: rawData, encoding: .utf8) ?? ""
            return Translation(text: text)
        }
        
        return try await client.postMultipart(path: "audio/translations", formData: formData)
    }
}
