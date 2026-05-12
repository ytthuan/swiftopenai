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

    /// Whether to allow insecure `http` / `ws` connections.
    ///
    /// When `true`, the client permits plain-text HTTP and WebSocket connections
    /// **only** to local and LAN hosts (localhost, 127.0.0.1, ::1, `.local`
    /// hostnames, and RFC 1918 private IPv4 ranges). Insecure connections to
    /// public hosts are always rejected regardless of this setting.
    ///
    /// Default is `false` — only `https` and `wss` are allowed.
    ///
    /// - Important: On Apple platforms you must also add an App Transport Security
    ///   exception in your `Info.plist` for the target host, or ATS will block the
    ///   connection at the OS level.
    public let allowInsecureRequests: Bool

    /// Maximum size in bytes for any single multipart upload part.
    ///
    /// When a part (e.g., file payload) exceeds this size, `MultipartFormData.encode`
    /// throws `OpenAIError.bufferOverflow` *before* allocating the request body, preventing
    /// unbounded memory growth at the trust boundary in server-side adopters.
    ///
    /// Default is 512 MB, matching OpenAI's Files API server-side limit.
    /// Set to `Int.max` to disable enforcement (caller assumes responsibility).
    ///
    /// - Note: On memory-constrained platforms (iOS, watchOS), set this explicitly
    ///   to a value appropriate to your process heap (e.g., 64 MB for iOS).
    public let maxMultipartPartSize: Int

    /// Maximum total size in bytes for the assembled multipart request body.
    ///
    /// When the sum of all parts plus framing overhead would exceed this size,
    /// `MultipartFormData.encode` throws `OpenAIError.bufferOverflow` *before* allocating
    /// the request body.
    ///
    /// Default is 1 GB, providing 2× headroom over the per-part default for multi-part
    /// uploads. Set to `Int.max` to disable enforcement.
    ///
    /// - Note: On memory-constrained platforms (iOS, watchOS), set this explicitly.
    public let maxMultipartBodySize: Int

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
        apiKeyHeaderName: String? = nil,
        allowInsecureRequests: Bool = false,
        maxMultipartPartSize: Int = 512 * 1024 * 1024,
        maxMultipartBodySize: Int = 1024 * 1024 * 1024
    ) {
        precondition(tokenProvider != nil || !apiKey.isEmpty, "SwiftOpenAI: API key must not be empty when no token provider is set")
        precondition(maxRetries >= 0, "SwiftOpenAI: maxRetries must be non-negative")
        precondition(retryDelay >= 0, "SwiftOpenAI: retryDelay must be non-negative")
        precondition(maxMultipartPartSize > 0, "SwiftOpenAI: maxMultipartPartSize must be positive")
        precondition(maxMultipartBodySize > 0, "SwiftOpenAI: maxMultipartBodySize must be positive")
        Self.validateURL(baseURL, allowInsecure: allowInsecureRequests)
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
        self.allowInsecureRequests = allowInsecureRequests
        self.maxMultipartPartSize = maxMultipartPartSize
        self.maxMultipartBodySize = maxMultipartBodySize
    }

    // MARK: - URL Validation

    /// Validates the base URL scheme, allowing insecure schemes only for local/LAN hosts.
    ///
    /// - `https` and `wss` are always accepted.
    /// - `http` and `ws` are accepted only when `allowInsecure` is `true` AND the host
    ///   is a recognised local or private-network address.
    /// - All other combinations trigger a `preconditionFailure` in every build configuration.
    static func validateURL(_ baseURL: URL, allowInsecure: Bool) {
        guard let scheme = baseURL.scheme?.lowercased() else { return }
        if scheme == "https" || scheme == "wss" { return }
        guard scheme == "http" || scheme == "ws" else {
            preconditionFailure("SwiftOpenAI: Base URL uses unsupported scheme '\(scheme)'.")
        }
        guard allowInsecure else {
            preconditionFailure(
                "SwiftOpenAI: Base URL uses insecure scheme '\(scheme)'. "
                + "Use HTTPS in production, or pass allowInsecureRequests: true for local development."
            )
        }
        guard let host = baseURL.host?.lowercased(), isLocalOrLAN(host) else {
            preconditionFailure(
                "SwiftOpenAI: Insecure scheme '\(scheme)' is only allowed for local/LAN hosts. "
                + "Host '\(baseURL.host ?? "")' appears to be a public address."
            )
        }
    }

    /// Returns `true` when `host` is a loopback, link-local, `.local`, or RFC 1918 address.
    static func isLocalOrLAN(_ host: String) -> Bool {
        // Loopback
        if host == "localhost" || host == "127.0.0.1" || host == "::1" {
            return true
        }
        // mDNS / Bonjour
        if host.hasSuffix(".local") {
            return true
        }
        // RFC 1918 private IPv4 ranges — require exact dotted-quad (4 segments, all numeric)
        let parts = host.split(separator: ".")
        if parts.count == 4,
           let o0 = UInt8(parts[0]), let o1 = UInt8(parts[1]),
           let _ = UInt8(parts[2]), let _ = UInt8(parts[3])
        {
            if o0 == 10 { return true }                          // 10.0.0.0/8
            if o0 == 172, (16...31).contains(o1) { return true } // 172.16.0.0/12
            if o0 == 192, o1 == 168 { return true }              // 192.168.0.0/16
        }
        return false
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
