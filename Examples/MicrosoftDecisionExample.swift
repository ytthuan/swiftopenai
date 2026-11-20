// Standalone reference file — NOT compiled by the SwiftOpenAI package.
// Copy into an executable target depending on SwiftOpenAI and call:
// try await microsoftDecisionExample()          // Native Azure AI Foundry (`client.systemOne`)
// try await microsoftDecisionProxyExample()     // LiteLLM/OpenAI-compatible proxy (`client.decisions`)

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import SwiftOpenAI

private struct MicrosoftDecisionSettings: Decodable {
    let url: URL
    let apiKey: String
    let deployment: String?
}

private enum MicrosoftDecisionExampleError: Error, LocalizedError {
    case invalidSettings
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidSettings:
            return "Provide a settings JSON file ({url, apiKey}) or set AZURE_ENDPOINT with AZURE_ENTRA_TOKEN or AZURE_API_KEY. AZURE_DEPLOYMENT_NAME defaults to Decision-1.1."
        case .invalidResponse:
            return "Decision-1.1 returned unexpected answer types."
        case .requestFailed(let message):
            return message
        }
    }
}

private func validateDecisionEndpoint(_ url: URL) throws -> Bool {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let scheme = components.scheme?.lowercased(),
          let host = components.host?.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".[]")),
          !host.isEmpty,
          host != "api.openai.com",
          components.query == nil, components.fragment == nil,
          components.user == nil, components.password == nil else {
        throw MicrosoftDecisionExampleError.invalidSettings
    }
    let loopbackHosts = ["localhost", "127.0.0.1", "::1"]
    guard scheme == "https" || (scheme == "http" && loopbackHosts.contains(host)) else {
        throw MicrosoftDecisionExampleError.invalidSettings
    }
    return scheme == "http"
}

private func loadDecisionSettings(from settingsURL: URL) throws -> MicrosoftDecisionSettings {
    let settings: MicrosoftDecisionSettings
    do {
        settings = try JSONDecoder().decode(MicrosoftDecisionSettings.self, from: Data(contentsOf: settingsURL))
    } catch {
        throw MicrosoftDecisionExampleError.invalidSettings
    }
    guard !settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw MicrosoftDecisionExampleError.invalidSettings
    }
    return settings
}

/// Calls the native Microsoft Decision-1.1 endpoint through `client.systemOne.create(...)`.
///
/// Pass `settingsURL` pointing to a JSON file containing `url` and `apiKey` (plus optional
/// `deployment`), or set `AZURE_ENDPOINT` with `AZURE_ENTRA_TOKEN` or `AZURE_API_KEY`
/// (and optional `AZURE_DEPLOYMENT_NAME`, default: `Decision-1.1`). When `settingsURL` is
/// omitted and `AZURE_ENDPOINT` is unset, falls back to `~/.config/swiftopenai/settings.json`.
///
/// `client.systemOne` strips known Foundry route suffixes (`/openai/v1`, `/openai`, `/models`,
/// `/v1`, `/api/projects/<project>/...`) before posting to `/providers/microsoft/v1/systemone`.
/// Credentials are read at runtime and redacted from errors.
func microsoftDecisionExample(
    state: SystemOneState = .text("The API returns 500 on every call. This is my third report and all customers are blocked."),
    settingsURL: URL? = nil,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    session: URLSession? = nil
) async throws {
    let endpoint: URL
    let token: String
    let apiKey: String
    let deployment: String
    let useBearerForAPIKey: Bool

    let envEndpoint = environment["AZURE_ENDPOINT"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if let settingsURL {
        let settings = try loadDecisionSettings(from: settingsURL)
        endpoint = settings.url
        token = ""
        apiKey = settings.apiKey
        deployment = settings.deployment?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Decision-1.1"
        useBearerForAPIKey = endpoint.host?.lowercased().hasSuffix(".azure.com") != true
    } else if !envEndpoint.isEmpty, let parsed = URL(string: envEndpoint) {
        endpoint = parsed
        token = environment["AZURE_ENTRA_TOKEN"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        apiKey = environment["AZURE_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        deployment = environment["AZURE_DEPLOYMENT_NAME"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Decision-1.1"
        useBearerForAPIKey = false
        guard !token.isEmpty || !apiKey.isEmpty else {
            throw MicrosoftDecisionExampleError.invalidSettings
        }
    } else {
        let defaultFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/swiftopenai/settings.json")
        let settings = try loadDecisionSettings(from: defaultFile)
        endpoint = settings.url
        token = ""
        apiKey = settings.apiKey
        deployment = settings.deployment?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Decision-1.1"
        useBearerForAPIKey = endpoint.host?.lowercased().hasSuffix(".azure.com") != true
    }

    let allowInsecure = try validateDecisionEndpoint(endpoint)
    let provider: (any TokenProvider)? = token.isEmpty ? nil : StaticTokenProvider(token: token)
    let apiKeyHeaderName: String? = (token.isEmpty && !useBearerForAPIKey) ? "api-key" : nil
    let client = OpenAI(
        apiKey: apiKey,
        baseURL: endpoint,
        timeoutInterval: 30,
        maxRetries: 0,
        tokenProvider: provider,
        apiKeyHeaderName: apiKeyHeaderName,
        allowInsecureRequests: allowInsecure,
        session: session
    )
    defer { client.shutdown() }

    do {
        let start = ContinuousClock.now
        let response = try await client.systemOne.create(
            model: deployment,
            state: state,
            questions: [
                "team": .choice(
                    instructions: "Which team should handle this ticket?",
                    criteria: [
                        "billing": "Charges, invoices, and refunds",
                        "engineering": "Bugs, errors, and outages",
                        "support": "How-to and account questions",
                    ]
                ),
                "severity": .score(
                    instructions: "How severe is this incident?",
                    criteria: ["Cosmetic", "Minor", "Major", "Critical"]
                ),
                "repeat_contact": .noul(
                    instructions: "Has the customer contacted support before?"
                ),
            ]
        )
        let elapsed = start.duration(to: .now)
        guard case .choice(let teamChoice, let teamConfidence, let teamProbabilities) = response.answers["team"],
              case .score(let severityScore, let severityConfidence, let severityProbabilities, let severityLegend) = response.answers["severity"],
              case .noul(let repeatProbability) = response.answers["repeat_contact"] else {
            throw MicrosoftDecisionExampleError.invalidResponse
        }
        print("Model: \(response.model)")
        print("team: \(teamChoice), confidence=\(teamConfidence)")
        print("team probabilities: \(teamProbabilities)")
        print("severity: \(severityScore), confidence=\(severityConfidence)")
        print("severity probabilities: \(severityProbabilities)")
        print("severity legend: \(severityLegend ?? [:])")
        print("repeat_contact: probability=\(repeatProbability)")
        print("Tokens: input=\(response.usage.inputTokens), output=\(response.usage.outputTokens)")
        print("Complete response latency: \(elapsed)")
    } catch {
        var message = error.localizedDescription
        for secret in [token, apiKey] where !secret.isEmpty {
            message = message.replacingOccurrences(of: secret, with: "<redacted>")
        }
        throw MicrosoftDecisionExampleError.requestFailed(message)
    }
}

/// Calls `Decision-1.1` through an OpenAI-compatible proxy (such as LiteLLM at `/v1/decisions`).
///
/// Reads `url` and `apiKey` (plus optional `deployment`, default `"Decision-1.1"`) from
/// `settingsURL` (default: `~/.config/swiftopenai/settings.json`). Use this when routing
/// `Decision-1.1` through a LiteLLM proxy that exposes `/v1/decisions` and translates to
/// Azure AI Foundry's native `/providers/microsoft/v1/systemone`.
func microsoftDecisionProxyExample(
    settingsURL: URL? = nil,
    session: URLSession? = nil
) async throws {
    let settingsFile = settingsURL ?? FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/swiftopenai/settings.json")
    let settings = try loadDecisionSettings(from: settingsFile)
    let allowInsecure = try validateDecisionEndpoint(settings.url)
    let deployment = settings.deployment?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Decision-1.1"

    let client = OpenAI(
        apiKey: settings.apiKey,
        baseURL: settings.url,
        timeoutInterval: 30,
        maxRetries: 0,
        allowInsecureRequests: allowInsecure,
        session: session
    )
    defer { client.shutdown() }

    do {
        let start = ContinuousClock.now
        let decision = try await client.decisions.create(
            model: deployment,
            input: .text("The API returns 500 on every call. This is my third report and all customers are blocked."),
            questions: [
                .choice(
                    instructions: .text("Which team should handle this ticket?"),
                    choices: [
                        .init(value: "billing", description: "Charges, invoices, and refunds"),
                        .init(value: "engineering", description: "Bugs, errors, and outages"),
                        .init(value: "support", description: "How-to and account questions"),
                    ],
                    name: "team"
                ),
                .score(
                    instructions: .text("How severe is this incident?"),
                    levels: [
                        .init(label: "Cosmetic"),
                        .init(label: "Minor"),
                        .init(label: "Major"),
                        .init(label: "Critical"),
                    ],
                    name: "severity"
                ),
                .predicate(
                    instructions: .text("Has the customer contacted support before?"),
                    name: "repeat_contact"
                ),
            ]
        )
        let elapsed = start.duration(to: .now)
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
        print("Complete response latency: \(elapsed)")
    } catch {
        let message = error.localizedDescription.replacingOccurrences(of: settings.apiKey, with: "<redacted>")
        throw MicrosoftDecisionExampleError.requestFailed(message)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
