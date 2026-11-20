import Foundation

/// Access the native Microsoft Azure AI Foundry System One API (`POST /providers/microsoft/v1/systemone`).
///
/// Use `client.systemOne` explicitly for Microsoft `Decision-1.1` / `Decision-1`
/// deployments on Azure AI Foundry. Use `client.decisions` for the OpenAI
/// `/decisions` API (`gpt-6-luna`).
///
/// Known Azure AI Foundry base URL route suffixes (`/openai/v1`, `/openai`,
/// `/models`, `/v1`, and `/api/projects/<project>` with optional route suffixes)
/// are stripped automatically before appending `/providers/microsoft/v1/systemone`.
/// Custom non-Foundry base paths are preserved with the native path appended.
public struct SystemOne: Sendable {
    static let nativePath = "/providers/microsoft/v1/systemone"
    private static let providerBasePath = "/providers/microsoft/v1"

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    /// Evaluates named questions against shared state through the native System One endpoint.
    ///
    /// - Parameter request: Complete System One deployment name, state, named questions, and optional assets.
    /// - Returns: Typed named answers (`noul`, `choice`, `score`, or forward-compatible `.other`) and token usage.
    public func create(request: SystemOneCreateRequest) async throws -> SystemOneResponse {
        let resolvedPath = Self.resolvePath(basePath: client.basePath)
        return try await client.postResolved(path: resolvedPath, body: request)
    }

    /// Evaluates named `noul`, `choice`, and `score` questions against shared state.
    ///
    /// - Parameters:
    ///   - model: Azure AI Foundry deployment name (for example `"Decision-1.1"`).
    ///   - state: Shared plain-text or structured JSON state.
    ///   - questions: Named questions to evaluate; response answers use the same keys.
    ///   - assets: Optional named assets (such as base64 images) referenced in `state` or questions.
    /// - Returns: Typed named answers and token usage.
    public func create(
        model: String,
        state: SystemOneState,
        questions: [String: SystemOneQuestion],
        assets: [String: SystemOneAsset]? = nil
    ) async throws -> SystemOneResponse {
        try await create(request: SystemOneCreateRequest(
            model: model,
            state: state,
            questions: questions,
            assets: assets
        ))
    }

    /// Normalizes a configured base URL path for `/providers/microsoft/v1/systemone`.
    static func resolvePath(basePath: String) -> String {
        var trimmed = basePath
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        if trimmed.isEmpty {
            return nativePath
        }

        let normalized = trimmed.hasPrefix("/") ? trimmed : "/" + trimmed
        if normalized.hasSuffix(nativePath) {
            return normalized
        }
        if normalized.hasSuffix(providerBasePath) {
            return normalized + "/systemone"
        }

        let segments = normalized.split(separator: "/", omittingEmptySubsequences: true)
        if isFoundryRoutePath(segments) {
            return nativePath
        }

        return normalized + nativePath
    }

    private static func isFoundryRoutePath(_ segments: [Substring]) -> Bool {
        switch segments {
        case ["openai", "v1"], ["openai"], ["models"], ["v1"]:
            return true
        default:
            break
        }
        if segments.count >= 3 && segments[0] == "api" && segments[1] == "projects" {
            let suffix = Array(segments.dropFirst(3))
            switch suffix {
            case [], ["openai", "v1"], ["openai"], ["models"], ["v1"]:
                return true
            default:
                return false
            }
        }
        return false
    }
}
