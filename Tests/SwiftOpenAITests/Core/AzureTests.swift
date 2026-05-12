import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SwiftOpenAI

@Suite struct AzureConfigurationTests {

    @Test func defaultQueryItemsEmptyByDefault() {
        let config = Configuration(apiKey: "test-key")
        #expect(config.defaultQueryItems.isEmpty)
    }

    @Test func defaultQueryItemsPreserved() {
        let items = [URLQueryItem(name: "api-version", value: "2025-11-15-preview")]
        let config = Configuration(apiKey: "test-key", defaultQueryItems: items)
        #expect(config.defaultQueryItems.count == 1)
        #expect(config.defaultQueryItems.first?.name == "api-version")
        #expect(config.defaultQueryItems.first?.value == "2025-11-15-preview")
    }

    @Test func tokenProviderNilByDefault() {
        let config = Configuration(apiKey: "test-key")
        #expect(config.tokenProvider == nil)
    }

    @Test func tokenProviderAccepted() {
        let provider = StaticTokenProvider(token: "test-token")
        let config = Configuration(apiKey: "", tokenProvider: provider)
        #expect(config.tokenProvider != nil)
    }

    @Test func emptyApiKeyAllowedWithTokenProvider() {
        let provider = StaticTokenProvider(token: "test-token")
        // Should not crash — apiKey can be empty when tokenProvider is set
        let config = Configuration(apiKey: "", tokenProvider: provider)
        #expect(config.apiKey.isEmpty)
    }
}

@Suite struct AzureInitializerTests {

    @Test func azureResourceInitializer() {
        let client = OpenAI.azure(resourceName: "my-resource", apiKey: "test-key")
        #expect(client.configuration.baseURL.absoluteString == "https://my-resource.openai.azure.com/openai/v1")
        #expect(client.configuration.apiKey == "test-key")
        #expect(client.configuration.defaultQueryItems.isEmpty)
        #expect(client.configuration.tokenProvider == nil)
        #expect(client.configuration.apiKeyHeaderName == "api-key")
    }

    @Test func azureResourceCustomSuffix() {
        let client = OpenAI.azure(
            resourceName: "my-resource",
            apiKey: "test-key",
            endpointSuffix: "services.ai.azure.com"
        )
        #expect(client.configuration.baseURL.absoluteString == "https://my-resource.services.ai.azure.com/openai/v1")
    }

    @Test func azureFoundryEntraIDInitializer() {
        let client = OpenAI.azureFoundry(
            endpoint: "https://myaccount.services.ai.azure.com/api/projects/myproject",
            tenantId: "tenant-123",
            clientId: "client-456",
            clientSecret: "secret-789"
        )
        #expect(client.configuration.baseURL.absoluteString == "https://myaccount.services.ai.azure.com/api/projects/myproject/openai")
        #expect(client.configuration.defaultQueryItems.count == 1)
        #expect(client.configuration.defaultQueryItems.first?.name == "api-version")
        #expect(client.configuration.defaultQueryItems.first?.value == "2025-11-15-preview")
        #expect(client.configuration.tokenProvider != nil)
    }

    @Test func azureFoundryTrailingSlashHandled() {
        let client = OpenAI.azureFoundry(
            endpoint: "https://myaccount.services.ai.azure.com/api/projects/myproject/",
            tenantId: "t", clientId: "c", clientSecret: "s"
        )
        #expect(client.configuration.baseURL.absoluteString == "https://myaccount.services.ai.azure.com/api/projects/myproject/openai")
    }

    @Test func azureFoundryCustomApiVersion() {
        let client = OpenAI.azureFoundry(
            endpoint: "https://x.services.ai.azure.com/api/projects/p",
            tenantId: "t", clientId: "c", clientSecret: "s",
            apiVersion: "2024-10-21"
        )
        #expect(client.configuration.defaultQueryItems.first?.value == "2024-10-21")
    }

    @Test func azureFoundryStaticTokenInitializer() {
        let client = OpenAI.azureFoundry(
            endpoint: "https://myaccount.services.ai.azure.com/api/projects/myproject",
            token: "eyJ0eXAi..."
        )
        #expect(client.configuration.baseURL.absoluteString == "https://myaccount.services.ai.azure.com/api/projects/myproject/openai")
        #expect(client.configuration.tokenProvider != nil)
        #expect(client.configuration.defaultQueryItems.first?.name == "api-version")
    }

    // MARK: - Multipart Limit Forwarding

    @Test func azureConvenienceInitForwardsMultipartLimits() {
        let client = OpenAI.azure(
            resourceName: "my-resource",
            apiKey: "test-key",
            maxMultipartPartSize: 64 * 1024 * 1024,
            maxMultipartBodySize: 128 * 1024 * 1024
        )
        #expect(client.configuration.maxMultipartPartSize == 64 * 1024 * 1024)
        #expect(client.configuration.maxMultipartBodySize == 128 * 1024 * 1024)
    }

    @Test func azureFoundryEntraIdConvenienceInitForwardsMultipartLimits() {
        let client = OpenAI.azureFoundry(
            endpoint: "https://myaccount.services.ai.azure.com/api/projects/myproject",
            tenantId: "t",
            clientId: "c",
            clientSecret: "s",
            maxMultipartPartSize: 32 * 1024 * 1024,
            maxMultipartBodySize: 64 * 1024 * 1024
        )
        #expect(client.configuration.maxMultipartPartSize == 32 * 1024 * 1024)
        #expect(client.configuration.maxMultipartBodySize == 64 * 1024 * 1024)
    }

    @Test func azureFoundryTokenConvenienceInitForwardsMultipartLimits() {
        let client = OpenAI.azureFoundry(
            endpoint: "https://myaccount.services.ai.azure.com/api/projects/myproject",
            token: "eyJ0eXAi...",
            maxMultipartPartSize: 16 * 1024 * 1024,
            maxMultipartBodySize: 48 * 1024 * 1024
        )
        #expect(client.configuration.maxMultipartPartSize == 16 * 1024 * 1024)
        #expect(client.configuration.maxMultipartBodySize == 48 * 1024 * 1024)
    }

    @Test func azureConvenienceInitsDefaultMultipartLimits() {
        let azureClient = OpenAI.azure(resourceName: "r", apiKey: "k")
        let foundryEntraClient = OpenAI.azureFoundry(
            endpoint: "https://x.services.ai.azure.com/api/projects/p",
            tenantId: "t", clientId: "c", clientSecret: "s"
        )
        let foundryTokenClient = OpenAI.azureFoundry(
            endpoint: "https://x.services.ai.azure.com/api/projects/p",
            token: "tok"
        )

        for client in [azureClient, foundryEntraClient, foundryTokenClient] {
            #expect(client.configuration.maxMultipartPartSize == 512 * 1024 * 1024)
            #expect(client.configuration.maxMultipartBodySize == 1024 * 1024 * 1024)
        }
    }
}

@Suite struct TokenProviderTests {

    @Test func staticTokenProviderReturnsToken() async throws {
        let provider = StaticTokenProvider(token: "my-test-token")
        let token = try await provider.getToken()
        #expect(token == "my-test-token")
    }

    @Test func entraIDTokenProviderCreation() {
        // Just verify it can be created without crashing
        let provider = EntraIDTokenProvider(
            tenantId: "tenant-id",
            clientId: "client-id",
            clientSecret: "client-secret"
        )
        #expect(provider is EntraIDTokenProvider)
    }
}

@Suite struct DefaultQueryItemsMergeTests {

    @Test func defaultQueryItemsIncludedInRequests() throws {
        let config = Configuration(
            apiKey: "test-key",
            defaultQueryItems: [URLQueryItem(name: "api-version", value: "2025-11-15-preview")]
        )
        let httpClient = HTTPClient(configuration: config)
        let request = try httpClient.buildRequest(path: "chat/completions", method: "POST")
        let url = request.url!.absoluteString
        #expect(url.contains("api-version=2025-11-15-preview"))
    }

    @Test func defaultAndPerRequestQueryItemsMerged() throws {
        let config = Configuration(
            apiKey: "test-key",
            defaultQueryItems: [URLQueryItem(name: "api-version", value: "2025-11-15-preview")]
        )
        let httpClient = HTTPClient(configuration: config)
        let request = try httpClient.buildRequest(
            path: "models",
            method: "GET",
            queryItems: [URLQueryItem(name: "limit", value: "10")]
        )
        let url = request.url!.absoluteString
        #expect(url.contains("api-version=2025-11-15-preview"))
        #expect(url.contains("limit=10"))
    }

    @Test func noDefaultQueryItemsWhenEmpty() throws {
        let config = Configuration(apiKey: "test-key")
        let httpClient = HTTPClient(configuration: config)
        let request = try httpClient.buildRequest(path: "models", method: "GET")
        let url = request.url!.absoluteString
        #expect(!url.contains("?"))
    }

    @Test func tokenProviderSkipsStaticAuth() throws {
        let provider = StaticTokenProvider(token: "dynamic-token")
        let config = Configuration(apiKey: "", tokenProvider: provider)
        let httpClient = HTTPClient(configuration: config)
        let request = try httpClient.buildRequest(path: "test", method: "GET")
        // Static auth header should NOT be present
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func staticApiKeyIncludesAuthHeader() throws {
        let config = Configuration(apiKey: "my-api-key")
        let httpClient = HTTPClient(configuration: config)
        let request = try httpClient.buildRequest(path: "test", method: "GET")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer my-api-key")
    }

    @Test func azureApiKeyHeaderUsesCustomName() throws {
        let config = Configuration(apiKey: "my-azure-key", apiKeyHeaderName: "api-key")
        let httpClient = HTTPClient(configuration: config)
        let request = try httpClient.buildRequest(path: "test", method: "GET")
        #expect(request.value(forHTTPHeaderField: "api-key") == "my-azure-key")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }
}
