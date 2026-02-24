import Foundation

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

    // MARK: - Resources

    // TODO: Add resource accessors as they are implemented:
    // public var chat: ChatResource { ... }
    // public var models: ModelsResource { ... }
    // public var embeddings: EmbeddingsResource { ... }
    // public var images: ImagesResource { ... }
    // public var audio: AudioResource { ... }
    // public var files: FilesResource { ... }
    // public var fineTuning: FineTuningResource { ... }
    // public var moderations: ModerationsResource { ... }
    // public var responses: ResponsesResource { ... }
    // public var batches: BatchesResource { ... }
    // public var uploads: UploadsResource { ... }
    // public var vectorStores: VectorStoresResource { ... }

    // MARK: - Initialization

    /// Creates a new OpenAI client.
    ///
    /// - Parameters:
    ///   - apiKey: Your OpenAI API key.
    ///   - organization: Optional organization ID.
    ///   - project: Optional project ID.
    ///   - baseURL: Override the default API base URL.
    ///   - timeoutInterval: Request timeout in seconds (default: 600).
    public init(
        apiKey: String,
        organization: String? = nil,
        project: String? = nil,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        timeoutInterval: TimeInterval = 600
    ) {
        self.configuration = Configuration(
            apiKey: apiKey,
            organization: organization,
            project: project,
            baseURL: baseURL,
            timeoutInterval: timeoutInterval
        )
    }
}
