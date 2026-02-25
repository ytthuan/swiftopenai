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
    ///   - session: Optional custom URLSession for testing.
    public init(
        apiKey: String,
        organization: String? = nil,
        project: String? = nil,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        timeoutInterval: TimeInterval = 600,
        maxRetries: Int = 2,
        retryDelay: TimeInterval = 0.5,
        session: URLSession? = nil
    ) {
        self.configuration = Configuration(
            apiKey: apiKey,
            organization: organization,
            project: project,
            baseURL: baseURL,
            timeoutInterval: timeoutInterval,
            maxRetries: maxRetries,
            retryDelay: retryDelay
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
}
