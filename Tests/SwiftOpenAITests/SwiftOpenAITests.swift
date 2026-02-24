import Testing
@testable import SwiftOpenAI

@Test func clientInitialization() async throws {
    let client = OpenAI(apiKey: "test-key")
    #expect(client.configuration.apiKey == "test-key")
    #expect(client.configuration.baseURL.absoluteString == "https://api.openai.com/v1")
}

@Test func configurationDefaults() async throws {
    let config = Configuration(apiKey: "sk-test")
    #expect(config.organization == nil)
    #expect(config.project == nil)
    #expect(config.timeoutInterval == 600)
}

@Test func configurationCustom() async throws {
    let config = Configuration(
        apiKey: "sk-test",
        organization: "org-123",
        project: "proj-456",
        timeoutInterval: 30
    )
    #expect(config.organization == "org-123")
    #expect(config.project == "proj-456")
    #expect(config.timeoutInterval == 30)
}

