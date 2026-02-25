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

    public init(
        apiKey: String,
        organization: String? = nil,
        project: String? = nil,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        timeoutInterval: TimeInterval = 600
    ) {
        precondition(!apiKey.isEmpty, "SwiftOpenAI: API key must not be empty")
        Self.validateSecureURL(baseURL)
        self.apiKey = apiKey
        self.organization = organization
        self.project = project
        self.baseURL = baseURL
        self.timeoutInterval = timeoutInterval
    }

    /// Validates that the base URL uses a secure scheme.
    /// Logs a warning for non-HTTPS URLs in debug builds.
    static func validateSecureURL(_ baseURL: URL) {
        #if DEBUG
        if let scheme = baseURL.scheme?.lowercased(), scheme != "https", scheme != "wss" {
            print("⚠️ SwiftOpenAI: Base URL uses insecure scheme '\(scheme)'. Use HTTPS in production.")
        }
        #endif
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
