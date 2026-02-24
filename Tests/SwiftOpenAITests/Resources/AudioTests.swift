import Foundation
import Testing
@testable import SwiftOpenAI

// MARK: - Tests

extension MockAPITests {

    @Test func createTranscription() async throws {
        let json = """
        {
            "text": "Hello world"
        }
        """
        let client = makeMockClient(json: json)
        let response = try await client.audio.transcriptions.create(
            file: Data("fake audio".utf8),
            filename: "audio.mp3",
            model: "whisper-1"
        )

        #expect(response.text == "Hello world")

        let requestURL = MockURLProtocol.lastRequest?.url?.absoluteString
        #expect(requestURL?.contains("audio/transcriptions") == true)
    }

    @Test func createTranslation() async throws {
        let json = """
        {
            "text": "Translated text"
        }
        """
        let client = makeMockClient(json: json)
        let response = try await client.audio.translations.create(
            file: Data("fake audio".utf8),
            filename: "audio.mp3",
            model: "whisper-1"
        )

        #expect(response.text == "Translated text")

        let requestURL = MockURLProtocol.lastRequest?.url?.absoluteString
        #expect(requestURL?.contains("audio/translations") == true)
    }
}
