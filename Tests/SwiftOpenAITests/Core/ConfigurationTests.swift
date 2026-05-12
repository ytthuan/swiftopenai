import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SwiftOpenAI

// MARK: - isLocalOrLAN Host Classification

@Suite struct IsLocalOrLANTests {

    // Loopback addresses
    @Test func localhostIsLocal() {
        #expect(Configuration.isLocalOrLAN("localhost") == true)
    }

    @Test func ipv4LoopbackIsLocal() {
        #expect(Configuration.isLocalOrLAN("127.0.0.1") == true)
    }

    @Test func ipv6LoopbackIsLocal() {
        #expect(Configuration.isLocalOrLAN("::1") == true)
    }

    // mDNS / Bonjour
    @Test func dotLocalHostIsLocal() {
        #expect(Configuration.isLocalOrLAN("my-mac.local") == true)
    }

    // RFC 1918 — 10.x.x.x
    @Test func rfc1918TenNetIsLAN() {
        #expect(Configuration.isLocalOrLAN("10.0.0.1") == true)
        #expect(Configuration.isLocalOrLAN("10.255.255.255") == true)
    }

    // RFC 1918 — 172.16–31.x.x
    @Test func rfc1918OneSeventyTwoNetIsLAN() {
        #expect(Configuration.isLocalOrLAN("172.16.0.1") == true)
        #expect(Configuration.isLocalOrLAN("172.31.255.255") == true)
    }

    @Test func oneSeventyTwoOutsideRangeIsNotLAN() {
        #expect(Configuration.isLocalOrLAN("172.15.0.1") == false)
        #expect(Configuration.isLocalOrLAN("172.32.0.1") == false)
    }

    // RFC 1918 — 192.168.x.x
    @Test func rfc1918OneNinetyTwoNetIsLAN() {
        #expect(Configuration.isLocalOrLAN("192.168.1.42") == true)
        #expect(Configuration.isLocalOrLAN("192.168.0.1") == true)
    }

    // Public addresses
    @Test func publicIPIsNotLAN() {
        #expect(Configuration.isLocalOrLAN("8.8.8.8") == false)
        #expect(Configuration.isLocalOrLAN("1.1.1.1") == false)
    }

    @Test func publicHostnameIsNotLAN() {
        #expect(Configuration.isLocalOrLAN("api.openai.com") == false)
        #expect(Configuration.isLocalOrLAN("example.com") == false)
    }

    // Regression: crafted hostnames embedding RFC 1918 IPs must NOT match
    @Test func craftedTenNetHostnameIsNotLAN() {
        #expect(Configuration.isLocalOrLAN("10.0.0.1.evil.com") == false)
    }

    @Test func craftedOneNinetyTwoHostnameIsNotLAN() {
        #expect(Configuration.isLocalOrLAN("192.168.1.1.evil.com") == false)
    }

    @Test func craftedOneSeventyTwoHostnameIsNotLAN() {
        #expect(Configuration.isLocalOrLAN("172.16.0.1.evil.com") == false)
    }

    @Test func craftedLocalhostSubdomainIsNotLAN() {
        #expect(Configuration.isLocalOrLAN("localhost.evil.com") == false)
    }

    @Test func craftedLoopbackHostnameIsNotLAN() {
        #expect(Configuration.isLocalOrLAN("127.0.0.1.evil.com") == false)
    }
}

// MARK: - validateURL

@Suite struct ValidateURLTests {

    @Test func httpsIsAlwaysAccepted() {
        // Should not trap
        Configuration.validateURL(URL(string: "https://api.openai.com/v1")!, allowInsecure: false)
        Configuration.validateURL(URL(string: "https://api.openai.com/v1")!, allowInsecure: true)
    }

    @Test func wssIsAlwaysAccepted() {
        Configuration.validateURL(URL(string: "wss://api.openai.com/v1/realtime")!, allowInsecure: false)
        Configuration.validateURL(URL(string: "wss://api.openai.com/v1/realtime")!, allowInsecure: true)
    }

    @Test func httpLocalhostAcceptedWhenOptIn() {
        // Should not trap
        Configuration.validateURL(URL(string: "http://localhost:8080/v1")!, allowInsecure: true)
    }

    @Test func httpPrivateIPAcceptedWhenOptIn() {
        Configuration.validateURL(URL(string: "http://192.168.1.100:8080/v1")!, allowInsecure: true)
    }

    @Test func httpTenNetAcceptedWhenOptIn() {
        Configuration.validateURL(URL(string: "http://10.0.0.5/v1")!, allowInsecure: true)
    }

    @Test func wsLocalhostAcceptedWhenOptIn() {
        Configuration.validateURL(URL(string: "ws://localhost:8080/v1")!, allowInsecure: true)
    }
}

// MARK: - Configuration init with allowInsecureRequests

@Suite struct InsecureConfigurationInitTests {

    @Test func httpLocalhostConfigurationCreates() {
        let config = Configuration(
            apiKey: "test-key",
            baseURL: URL(string: "http://localhost:8080/v1")!,
            allowInsecureRequests: true
        )
        #expect(config.baseURL.scheme == "http")
        #expect(config.baseURL.host == "localhost")
        #expect(config.allowInsecureRequests == true)
    }

    @Test func httpPrivateNetworkConfigurationCreates() {
        let config = Configuration(
            apiKey: "test-key",
            baseURL: URL(string: "http://192.168.1.42:11434/v1")!,
            allowInsecureRequests: true
        )
        #expect(config.baseURL.host == "192.168.1.42")
        #expect(config.allowInsecureRequests == true)
    }

    @Test func httpsStillWorksWithInsecureFlagOff() {
        let config = Configuration(
            apiKey: "test-key",
            baseURL: URL(string: "https://api.openai.com/v1")!,
            allowInsecureRequests: false
        )
        #expect(config.baseURL.scheme == "https")
        #expect(config.allowInsecureRequests == false)
    }

    @Test func httpsStillWorksWithInsecureFlagOn() {
        let config = Configuration(
            apiKey: "test-key",
            baseURL: URL(string: "https://api.openai.com/v1")!,
            allowInsecureRequests: true
        )
        #expect(config.baseURL.scheme == "https")
    }

    @Test func defaultAllowInsecureIsFalse() {
        let config = Configuration(apiKey: "test-key")
        #expect(config.allowInsecureRequests == false)
    }
}

// MARK: - OpenAI client with allowInsecureRequests

@Suite struct InsecureClientInitTests {

    @Test func openAIClientAcceptsHttpLocalhostWhenOptIn() {
        let client = OpenAI(
            apiKey: "test-key",
            baseURL: URL(string: "http://localhost:8080/v1")!,
            allowInsecureRequests: true
        )
        #expect(client.configuration.baseURL.scheme == "http")
        #expect(client.configuration.baseURL.host == "localhost")
        #expect(client.configuration.allowInsecureRequests == true)
    }

    @Test func openAIClientPassesThroughInsecureFlag() {
        let client = OpenAI(
            apiKey: "test-key",
            baseURL: URL(string: "http://10.0.0.5:11434/v1")!,
            allowInsecureRequests: true
        )
        #expect(client.configuration.allowInsecureRequests == true)
    }
}

// MARK: - websocketBaseURL with insecure opt-in

#if canImport(Darwin)
@Suite struct InsecureWebSocketURLTests {

    @Test func httpLocalhostConvertsToWs() {
        let config = Configuration(
            apiKey: "test-key",
            baseURL: URL(string: "http://localhost:8080/v1")!,
            allowInsecureRequests: true
        )
        let wsURL = config.websocketBaseURL
        #expect(wsURL.scheme == "ws")
        #expect(wsURL.host == "localhost")
        #expect(wsURL.port == 8080)
    }

    @Test func httpPrivateIPConvertsToWs() {
        let config = Configuration(
            apiKey: "test-key",
            baseURL: URL(string: "http://192.168.1.42:11434/v1")!,
            allowInsecureRequests: true
        )
        let wsURL = config.websocketBaseURL
        #expect(wsURL.scheme == "ws")
        #expect(wsURL.host == "192.168.1.42")
    }

    @Test func httpsStillConvertsToWss() {
        let config = Configuration(
            apiKey: "test-key",
            baseURL: URL(string: "https://api.openai.com/v1")!
        )
        let wsURL = config.websocketBaseURL
        #expect(wsURL.scheme == "wss")
    }
}
#endif

// MARK: - Multipart Size Limits

@Suite struct MultipartLimitTests {

    @Test func defaultMultipartLimits() {
        let config = Configuration(apiKey: "sk-test")
        #expect(config.maxMultipartPartSize == 512 * 1024 * 1024)
        #expect(config.maxMultipartBodySize == 1024 * 1024 * 1024)
    }

    @Test func customMultipartLimits() {
        let config = Configuration(
            apiKey: "sk-test",
            maxMultipartPartSize: 64 * 1024 * 1024,
            maxMultipartBodySize: 128 * 1024 * 1024
        )
        #expect(config.maxMultipartPartSize == 64 * 1024 * 1024)
        #expect(config.maxMultipartBodySize == 128 * 1024 * 1024)
    }

    @Test func multipartLimitOptOut() {
        let config = Configuration(
            apiKey: "sk-test",
            maxMultipartPartSize: .max,
            maxMultipartBodySize: .max
        )
        #expect(config.maxMultipartPartSize == Int.max)
        #expect(config.maxMultipartBodySize == Int.max)
    }
}

// MARK: - OpenAI init Multipart Limits Thread-Through

@Suite struct OpenAIMultipartInitTests {

    @Test func openAIInitThreadsMultipartLimitsToConfiguration() {
        let client = OpenAI(
            apiKey: "sk-test",
            maxMultipartPartSize: 12345,
            maxMultipartBodySize: 67890
        )
        #expect(client.configuration.maxMultipartPartSize == 12345)
        #expect(client.configuration.maxMultipartBodySize == 67890)
    }

    @Test func openAIInitDefaultsMatchConfigurationDefaults() {
        let client = OpenAI(apiKey: "sk-test")
        #expect(client.configuration.maxMultipartPartSize == 512 * 1024 * 1024)
        #expect(client.configuration.maxMultipartBodySize == 1024 * 1024 * 1024)
    }
}
