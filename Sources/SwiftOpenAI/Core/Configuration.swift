import Foundation

/// Holds client configuration for the OpenAI API.
public struct Configuration: Sendable {

    /// The API key used for authentication.
    public let apiKey: String

    /// Optional organization ID for API requests.
    public let organization: String?

    /// Optional project ID for API requests.
    public let project: String?

    /// Base URL for the OpenAI API.
    public let baseURL: URL

    /// Request timeout interval in seconds.
    public let timeoutInterval: TimeInterval

    /// Maximum number of retries for failed requests (429, 5xx). Default is 2. Set to 0 to disable.
    public let maxRetries: Int

    /// Base delay for exponential backoff in seconds. Default is 0.5.
    public let retryDelay: TimeInterval

    /// Default query items appended to every request URL.
    public let defaultQueryItems: [URLQueryItem]

    /// Optional token provider for dynamic authentication (e.g., Azure Entra ID).
    public let tokenProvider: (any TokenProvider)?

    /// Custom header name for API key authentication.
    /// When set (e.g., `"api-key"` for Azure), sends the raw key in this header
    /// instead of `Authorization: Bearer <key>`. Default is `nil` (uses Bearer).
    public let apiKeyHeaderName: String?

    public init(
        apiKey: String,
        organization: String? = nil,
        project: String? = nil,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        timeoutInterval: TimeInterval = 600,
        maxRetries: Int = 2,
        retryDelay: TimeInterval = 0.5,
        defaultQueryItems: [URLQueryItem] = [],
        tokenProvider: (any TokenProvider)? = nil,
        apiKeyHeaderName: String? = nil
    ) {
        precondition(tokenProvider != nil || !apiKey.isEmpty, "SwiftOpenAI: API key must not be empty when no token provider is set")
        precondition(maxRetries >= 0, "SwiftOpenAI: maxRetries must be non-negative")
        precondition(retryDelay >= 0, "SwiftOpenAI: retryDelay must be non-negative")
        Self.validateSecureURL(baseURL)
        self.apiKey = apiKey
        self.organization = organization
        self.project = project
        self.baseURL = baseURL
        self.timeoutInterval = timeoutInterval
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
        self.defaultQueryItems = defaultQueryItems
        self.tokenProvider = tokenProvider
        self.apiKeyHeaderName = apiKeyHeaderName
    }

    /// Validates that the base URL uses a secure scheme.
    /// Always compiled; uses `assertionFailure` so debug builds trap while release builds continue.
    static func validateSecureURL(_ baseURL: URL) {
        if let scheme = baseURL.scheme?.lowercased(), scheme != "https", scheme != "wss" {
            assertionFailure("SwiftOpenAI: Base URL uses insecure scheme '\(scheme)'. Use HTTPS in production to protect API keys.")
        }
    }

#if canImport(Darwin)
    /// Base URL for WebSocket connections derived from `baseURL`.
    public var websocketBaseURL: URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)
        let scheme = components?.scheme?.lowercased()
        if scheme == "https" {
            components?.scheme = "wss"
        } else if scheme == "http" {
            components?.scheme = "ws"
        }
        return components?.url ?? baseURL
    }
#endif
}
