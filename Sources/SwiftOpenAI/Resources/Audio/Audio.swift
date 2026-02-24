import Foundation

/// Namespace for Audio API resources.
public struct Audio: Sendable {
    /// Access audio transcriptions.
    public let transcriptions: Transcriptions
    /// Access audio translations.
    public let translations: Translations
    /// Access text-to-speech.
    public let speech: Speech

    init(client: HTTPClient) {
        self.transcriptions = Transcriptions(client: client)
        self.translations = Translations(client: client)
        self.speech = Speech(client: client)
    }
}
