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

    @Test func createSpeech() async throws {
        let fakeAudioBytes = Data([0x49, 0x44, 0x33, 0xFF, 0xFB, 0x90, 0x00])
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        MockURLProtocol.mockResponse = (
            fakeAudioBytes,
            HTTPURLResponse(
                url: URL(string: "https://api.openai.com/v1")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "audio/mpeg"]
            )!
        )

        let client = OpenAI(apiKey: "test-key", session: session)
        let result = try await client.audio.speech.create(
            model: "tts-1",
            input: "Hello world",
            voice: "alloy"
        )

        #expect(result == fakeAudioBytes)

        let requestURL = MockURLProtocol.lastRequest?.url?.absoluteString
        #expect(requestURL?.contains("audio/speech") == true)
    }
}
