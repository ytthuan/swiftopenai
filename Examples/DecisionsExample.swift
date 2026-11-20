// Standalone reference file — NOT compiled by the SwiftOpenAI package.
// Copy into an executable target depending on SwiftOpenAI and call:
// try await decisionsExample()

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import SwiftOpenAI

private struct DecisionsExampleSettings: Decodable {
    let url: URL
    let apiKey: String
}

private enum DecisionsExampleError: Error, LocalizedError {
    case invalidSettings
    case invalidProxyURL
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidSettings:
            return "Provide valid url and nonempty apiKey fields in ~/.config/swiftopenai/settings.json."
        case .invalidProxyURL:
            return "Use an HTTPS proxy URL or a loopback HTTP URL; api.openai.com is excluded from this example."
        case .requestFailed(let message):
            return message
        }
    }
}

/// Evaluates three Decisions question types with `gpt-6-luna` through the configured proxy.
///
/// Reads `url` and `apiKey` from `~/.config/swiftopenai/settings.json` at runtime.
/// Pass `settingsURL` to use a different settings file. Credentials are never printed.
/// An optional session supports offline HTTP mocking, as in the SDK unit tests.
func decisionsExample(settingsURL: URL? = nil, session: URLSession? = nil) async throws {
    let settingsFile = settingsURL ?? FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/swiftopenai/settings.json")
    let settings: DecisionsExampleSettings
    do {
        settings = try JSONDecoder().decode(DecisionsExampleSettings.self, from: Data(contentsOf: settingsFile))
    } catch {
        throw DecisionsExampleError.invalidSettings
    }
    guard !settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw DecisionsExampleError.invalidSettings
    }
    let scheme = settings.url.scheme?.lowercased()
    let host = settings.url.host?.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".[]"))
    let loopbackHosts = ["localhost", "127.0.0.1", "::1"]
    guard let host, !host.isEmpty, host != "api.openai.com",
          scheme == "https" || (scheme == "http" && loopbackHosts.contains(host)) else {
        throw DecisionsExampleError.invalidProxyURL
    }

    let client = OpenAI(
        apiKey: settings.apiKey,
        baseURL: settings.url,
        timeoutInterval: 30,
        maxRetries: 0,
        allowInsecureRequests: scheme == "http",
        session: session
    )
    defer { client.shutdown() }

    do {
        let decision = try await client.decisions.create(request: DecisionCreateRequest(
            model: "gpt-6-luna",
            input: .text("The package arrived with a broken screen. I need a refund."),
            questions: [
                .predicate(instructions: .text("Does the customer report a damaged item?"), name: "damaged"),
                .choice(
                    instructions: .text("Which department should handle this request?"),
                    choices: [
                        .init(value: "billing", description: "Refunds and payments"),
                        .init(value: "support", description: "Technical help"),
                        .init(value: "other", description: "Other requests"),
                    ],
                    name: "department"
                ),
                .score(
                    instructions: .text("How severe is the damage?"),
                    levels: [
                        .init(label: "Cosmetic"),
                        .init(label: "Usable", description: "Damaged but still works"),
                        .init(label: "Unusable", description: "Cannot be used"),
                    ],
                    name: "severity"
                ),
            ]
        ))

        print("Model: \(decision.model)")
        for answer in decision.answers {
            let name = answer.name ?? "unnamed"
            switch answer {
            case .predicate(_, let probability):
                print("\(name): probability=\(probability)")
            case .choice(_, let choice, let confidence, let probabilities):
                print("\(name): choice=\(choice), confidence=\(confidence), probabilities=\(probabilities)")
            case .score(_, let score, let confidence, let probabilities):
                print("\(name): score=\(score), confidence=\(confidence), probabilities=\(probabilities)")
            case .refusal:
                print("\(name): refused")
            case .other:
                print("\(name): unrecognized answer type")
            }
        }
        print("Tokens: input=\(decision.usage.inputTokens), output=\(decision.usage.outputTokens), total=\(decision.usage.totalTokens)")
        print("Cache: read=\(decision.usage.inputTokensDetails.cachedTokens), written=\(decision.usage.inputTokensDetails.cacheWriteTokens)")
    } catch {
        let message = error.localizedDescription.replacingOccurrences(of: settings.apiKey, with: "<redacted>")
        throw DecisionsExampleError.requestFailed(message)
    }
}
