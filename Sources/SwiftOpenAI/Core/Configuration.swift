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
        self.apiKey = apiKey
        self.organization = organization
        self.project = project
        self.baseURL = baseURL
        self.timeoutInterval = timeoutInterval
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
