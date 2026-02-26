import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A provider that returns auth tokens for API requests.
///
/// Implement this protocol to provide dynamic authentication tokens,
/// such as Azure Entra ID tokens that need periodic refresh.
public protocol TokenProvider: Sendable {
    /// Returns a valid authentication token.
    ///
    /// Implementations should cache tokens and refresh them before expiry.
    func getToken() async throws -> String
}

/// A token provider that returns a static, pre-obtained token.
///
/// Use this when you have a token from an external source (e.g., CLI, backend server).
/// Note: Static tokens expire and will not be refreshed automatically.
///
/// Usage:
/// ```swift
/// let provider = StaticTokenProvider(token: "eyJ0eXAi...")
/// ```
public struct StaticTokenProvider: TokenProvider {
    private let token: String

    public init(token: String) {
        self.token = token
    }

    public func getToken() async throws -> String {
        token
    }
}

/// A token provider that uses OAuth 2.0 client credentials flow to obtain
/// Azure Entra ID tokens for Azure AI Foundry and Azure OpenAI.
///
/// Tokens are cached and automatically refreshed 5 minutes before expiry
/// (~1 hour lifetime). Thread-safe via Swift actor isolation.
///
/// Usage:
/// ```swift
/// let provider = EntraIDTokenProvider(
///     tenantId: "your-tenant-id",
///     clientId: "your-client-id",
///     clientSecret: "your-client-secret"
/// )
/// let token = try await provider.getToken()
/// ```
public actor EntraIDTokenProvider: TokenProvider {

    private let tenantId: String
    private let clientId: String
    private let clientSecret: String
    private let scope: String
    private let session: URLSession

    private var cachedToken: String?
    private var expiresAt: Date?

    /// Creates a new Entra ID token provider using OAuth 2.0 client credentials.
    ///
    /// - Parameters:
    ///   - tenantId: Azure Entra ID tenant ID.
    ///   - clientId: Application (client) ID from Azure app registration.
    ///   - clientSecret: Client secret from Azure app registration.
    ///   - scope: OAuth scope. Default: `https://cognitiveservices.azure.com/.default`.
    ///   - session: URLSession to use for token requests. Default: `.shared`.
    public init(
        tenantId: String,
        clientId: String,
        clientSecret: String,
        scope: String = "https://cognitiveservices.azure.com/.default",
        session: URLSession = .shared
    ) {
        self.tenantId = tenantId
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.scope = scope
        self.session = session
    }

    public func getToken() async throws -> String {
        // Return cached token if still valid
        if let token = cachedToken, let expiry = expiresAt, Date() < expiry {
            return token
        }

        // Request new token via OAuth 2.0 client credentials flow
        let tokenURL = URL(string: "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyComponents = [
            "client_id=\(percentEncode(clientId))",
            "client_secret=\(percentEncode(clientSecret))",
            "scope=\(percentEncode(scope))",
            "grant_type=client_credentials"
        ]
        request.httpBody = bodyComponents.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.connectionError(message: "Bad response from Entra ID token endpoint")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenAIError.authenticationError(message: "Entra ID token request failed (\(httpResponse.statusCode)): \(body)")
        }

        let tokenResponse = try JSONDecoder().decode(EntraIDTokenResponse.self, from: data)

        // Cache with 5-minute safety margin
        cachedToken = tokenResponse.accessToken
        expiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn - 300))

        return tokenResponse.accessToken
    }

    /// Character set for application/x-www-form-urlencoded encoding (RFC 3986 unreserved).
    private static let formURLEncodedAllowed: CharacterSet = {
        var cs = CharacterSet.alphanumerics
        cs.insert(charactersIn: "-._~")
        return cs
    }()

    /// Percent-encodes a string for use in application/x-www-form-urlencoded body.
    private func percentEncode(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: Self.formURLEncodedAllowed) ?? string
    }
}

/// Response from the Entra ID token endpoint.
struct EntraIDTokenResponse: Codable {
    let accessToken: String
    let expiresIn: Int
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}
