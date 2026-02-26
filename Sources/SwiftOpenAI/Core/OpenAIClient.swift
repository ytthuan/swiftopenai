import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The main OpenAI client, providing access to all API resources.
///
/// Create an instance with your API key and use the resource properties
/// to interact with different endpoints:
///
/// ```swift
/// let client = OpenAI(apiKey: "sk-...")
/// let models = try await client.models.list()
/// ```
public final class OpenAI: Sendable {

    /// Configuration for this client instance.
    public let configuration: Configuration

    /// Internal HTTP client shared by all resources.
    let httpClient: HTTPClient

    // MARK: - Resources

    /// Access the Models API.
    public let models: Models

    /// Access the Embeddings API.
    public let embeddings: Embeddings

    /// Access the Moderations API.
    public let moderations: Moderations

    /// Access the Images API.
    public let images: Images

    /// Access the Audio API.
    public let audio: Audio

    /// Access the Files API.
    public let files: Files

    /// Access the Chat API.
    public let chat: Chat

    /// Access the Vector Stores API.
    public let vectorStores: VectorStores

    /// Access the Responses API.
    public let responses: Responses

    /// Access the Fine-tuning API.
    public let fineTuning: FineTuning

    /// Access the Batches API.
    public let batches: Batches

    /// Access the Completions API (legacy).
    public let completions: Completions

    /// Access the Uploads API.
    public let uploads: Uploads

    /// Access the Conversations API.
    public let conversations: Conversations

    #if canImport(Darwin)
    /// Access the Realtime API for low-latency bidirectional communication.
    public let realtime: Realtime
    #endif

    // MARK: - Initialization

    /// Creates a new OpenAI client.
    ///
    /// - Parameters:
    ///   - apiKey: Your OpenAI API key.
    ///   - organization: Optional organization ID.
    ///   - project: Optional project ID.
    ///   - baseURL: Override the default API base URL.
    ///   - timeoutInterval: Request timeout in seconds (default: 600).
    ///   - maxRetries: Maximum number of retries for failed requests (default: 2).
    ///   - retryDelay: Base delay for exponential backoff in seconds (default: 0.5).
    ///   - defaultQueryItems: Query items appended to every request URL.
    ///   - tokenProvider: Optional token provider for dynamic authentication (e.g., Azure Entra ID).
    ///   - apiKeyHeaderName: Custom header name for API key (e.g., `"api-key"` for Azure).
    ///   - session: Optional custom URLSession for testing.
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
        session: URLSession? = nil
    ) {
        self.configuration = Configuration(
            apiKey: apiKey,
            organization: organization,
            project: project,
            baseURL: baseURL,
            timeoutInterval: timeoutInterval,
            maxRetries: maxRetries,
            retryDelay: retryDelay,
            defaultQueryItems: defaultQueryItems,
            tokenProvider: tokenProvider,
            apiKeyHeaderName: apiKeyHeaderName
        )
        self.httpClient = HTTPClient(configuration: configuration, session: session)
        self.models = Models(client: httpClient)
        self.embeddings = Embeddings(client: httpClient)
        self.moderations = Moderations(client: httpClient)
        self.images = Images(client: httpClient)
        self.audio = Audio(client: httpClient)
        self.files = Files(client: httpClient)
        self.chat = Chat(client: httpClient)
        self.responses = Responses(client: httpClient)
        self.vectorStores = VectorStores(client: httpClient)
        self.fineTuning = FineTuning(client: httpClient)
        self.batches = Batches(client: httpClient)
        self.uploads = Uploads(client: httpClient)
        self.completions = Completions(client: httpClient)
        self.conversations = Conversations(client: httpClient)
        #if canImport(Darwin)
        self.realtime = Realtime(configuration: configuration)
        #endif
    }

    /// Shuts down the client by invalidating the underlying `URLSession`.
    ///
    /// Call this method when you are done using the client to release
    /// connection resources. After calling `shutdown()`, any in-flight
    /// requests will be cancelled and the client should not be reused.
    public func shutdown() {
        httpClient.session.invalidateAndCancel()
    }

    /// Pre-warms the HTTP connection by performing a lightweight API call.
    ///
    /// Call this method before making your first real request to eliminate
    /// TCP/TLS handshake latency from the critical path. The method fetches
    /// a minimal list of models (limit=1) to establish the connection.
    ///
    /// - Note: This makes a billable API call, but the overhead is negligible.
    ///
    /// Usage:
    /// ```swift
    /// let client = OpenAI(apiKey: "sk-...")
    /// try await client.warmConnection()
    /// // Subsequent requests benefit from the warm connection
    /// ```
    public func warmConnection() async throws {
        let _: ListResponse<Model> = try await httpClient.get(
            path: "models",
            queryItems: [URLQueryItem(name: "limit", value: "1")]
        )
    }
}

// MARK: - Azure Convenience Initializers

extension OpenAI {

    /// Creates an OpenAI client configured for Azure OpenAI v1 GA API.
    ///
    /// Uses API key authentication with the Azure resource-level endpoint.
    /// Works with chat completions, responses, embeddings, and other v1 GA APIs.
    ///
    /// Usage:
    /// ```swift
    /// let client = OpenAI.azure(
    ///     resourceName: "my-resource",
    ///     apiKey: "my-azure-api-key"
    /// )
    /// let response = try await client.chat.completions.create(
    ///     model: "gpt-4.1-nano",
    ///     messages: [.user(content: .text("Hello"))]
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - resourceName: Your Azure OpenAI resource name.
    ///   - apiKey: Your Azure OpenAI API key.
    ///   - endpointSuffix: Override endpoint domain. Default: `openai.azure.com`.
    ///   - timeoutInterval: Request timeout in seconds. Default: 600.
    ///   - maxRetries: Maximum retries for failed requests. Default: 2.
    ///   - session: Optional custom URLSession.
    public static func azure(
        resourceName: String,
        apiKey: String,
        endpointSuffix: String = "openai.azure.com",
        timeoutInterval: TimeInterval = 600,
        maxRetries: Int = 2,
        session: URLSession? = nil
    ) -> OpenAI {
        let baseURL = URL(string: "https://\(resourceName).\(endpointSuffix)/openai/v1")!
        return OpenAI(
            apiKey: apiKey,
            baseURL: baseURL,
            timeoutInterval: timeoutInterval,
            maxRetries: maxRetries,
            apiKeyHeaderName: "api-key",
            session: session
        )
    }

    /// Creates an OpenAI client configured for Azure AI Foundry project endpoint
    /// with Entra ID authentication (OAuth 2.0 client credentials).
    ///
    /// This is the recommended way to use Azure AI Foundry. It supports ALL OpenAI APIs
    /// including Conversations, Responses, Chat Completions, and more.
    ///
    /// The token provider automatically obtains and refreshes Entra ID tokens.
    ///
    /// Usage:
    /// ```swift
    /// let client = OpenAI.azureFoundry(
    ///     endpoint: "https://myresource.services.ai.azure.com/api/projects/myproject",
    ///     tenantId: "your-tenant-id",
    ///     clientId: "your-client-id",
    ///     clientSecret: "your-client-secret"
    /// )
    /// let conversation = try await client.conversations.create()
    /// let response = try await client.responses.create(
    ///     model: "gpt-4.1-nano",
    ///     input: .text("Hello")
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - endpoint: Azure AI Foundry project endpoint URL
    ///     (e.g., `https://myresource.services.ai.azure.com/api/projects/myproject`).
    ///   - tenantId: Azure Entra ID tenant ID.
    ///   - clientId: Application (client) ID from app registration.
    ///   - clientSecret: Client secret from app registration.
    ///   - apiVersion: Azure API version. Default: `2025-11-15-preview`.
    ///   - timeoutInterval: Request timeout in seconds. Default: 600.
    ///   - maxRetries: Maximum retries. Default: 2.
    ///   - session: Optional custom URLSession.
    public static func azureFoundry(
        endpoint: String,
        tenantId: String,
        clientId: String,
        clientSecret: String,
        apiVersion: String = "2025-11-15-preview",
        timeoutInterval: TimeInterval = 600,
        maxRetries: Int = 2,
        session: URLSession? = nil
    ) -> OpenAI {
        let cleanEndpoint = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let baseURL = URL(string: "\(cleanEndpoint)/openai")!

        let tokenProvider = EntraIDTokenProvider(
            tenantId: tenantId,
            clientId: clientId,
            clientSecret: clientSecret,
            scope: "https://ai.azure.com/.default"
        )

        return OpenAI(
            apiKey: "",
            baseURL: baseURL,
            timeoutInterval: timeoutInterval,
            maxRetries: maxRetries,
            defaultQueryItems: [URLQueryItem(name: "api-version", value: apiVersion)],
            tokenProvider: tokenProvider,
            session: session
        )
    }

    /// Creates an OpenAI client for Azure AI Foundry with a pre-obtained Entra ID token.
    ///
    /// Use this when you obtain tokens from an external source (e.g., CLI, backend).
    /// Note: The token will NOT be automatically refreshed.
    ///
    /// Usage:
    /// ```swift
    /// let token = "eyJ0eXAi..." // from `az account get-access-token`
    /// let client = OpenAI.azureFoundry(
    ///     endpoint: "https://myresource.services.ai.azure.com/api/projects/myproject",
    ///     token: token
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - endpoint: Azure AI Foundry project endpoint URL.
    ///   - token: Pre-obtained Entra ID bearer token.
    ///   - apiVersion: Azure API version. Default: `2025-11-15-preview`.
    ///   - timeoutInterval: Request timeout in seconds. Default: 600.
    ///   - maxRetries: Maximum retries. Default: 2.
    ///   - session: Optional custom URLSession.
    public static func azureFoundry(
        endpoint: String,
        token: String,
        apiVersion: String = "2025-11-15-preview",
        timeoutInterval: TimeInterval = 600,
        maxRetries: Int = 2,
        session: URLSession? = nil
    ) -> OpenAI {
        let cleanEndpoint = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let baseURL = URL(string: "\(cleanEndpoint)/openai")!

        return OpenAI(
            apiKey: "",
            baseURL: baseURL,
            timeoutInterval: timeoutInterval,
            maxRetries: maxRetries,
            defaultQueryItems: [URLQueryItem(name: "api-version", value: apiVersion)],
            tokenProvider: StaticTokenProvider(token: token),
            session: session
        )
    }
}
