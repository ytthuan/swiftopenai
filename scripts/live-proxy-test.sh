#!/usr/bin/env bash
# =============================================================================
# scripts/live-proxy-test.sh
# SwiftOpenAI — optional live-proxy smoke tests.
#
# Reads $SWIFTOPENAI_LIVE_PROXY (default: /tmp/pibochat-live-proxy.json) for
# connection details, then scaffolds a temporary Swift executable that imports
# SwiftOpenAI and exercises 11 SDK scenarios.
#
# Usage:
#   bash scripts/live-proxy-test.sh
#   SWIFTOPENAI_LIVE_PROXY=/path/to/config.json bash scripts/live-proxy-test.sh
#
# Config file schema (JSON):
#   {
#     "baseURL": "http://192.168.0.100:4000/v1",
#     "apiKey":  "sk-...",
#     "allowInsecureRequests": true,
#     "model": "gpt-5.4-nano"
#   }
#
# If the config file does NOT exist → prints a helpful notice and exits 0
#   (absence is expected in CI; this is NOT a failure).
# If the config file exists → runs all 11 scenarios and exits 1 if any failed.
#
# See .github/skills/live-proxy-test/SKILL.md for the full runner pattern.
#
# Hard rules (DO NOT violate):
#   - Never hit production OpenAI (api.openai.com). Use a local LiteLLM proxy.
#   - Never commit the proxy config file.
#   - Never hard-code the API key.
# =============================================================================

set -euo pipefail

PROXY_CONFIG="${SWIFTOPENAI_LIVE_PROXY:-/tmp/pibochat-live-proxy.json}"
ORIGINAL_PWD="$(pwd)"
RUNNER=""

# ---------------------------------------------------------------------------
# cleanup trap
# ---------------------------------------------------------------------------
# shellcheck disable=SC2329  # cleanup IS invoked via `trap cleanup EXIT`
cleanup() {
    if [[ -n "$RUNNER" ]] && [[ -d "$RUNNER" ]]; then
        rm -rf "$RUNNER"
        echo "Cleaned up runner: $RUNNER"
    fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# absent-file path — not a failure
# ---------------------------------------------------------------------------
if [[ ! -f "$PROXY_CONFIG" ]]; then
    echo "ℹ️  Live-proxy tests skipped: no config file found."
    echo ""
    echo "   To run live-proxy tests, create a config file at:"
    echo "     $PROXY_CONFIG"
    echo "   (or set \$SWIFTOPENAI_LIVE_PROXY to a custom path)"
    echo ""
    echo "   Config format:"
    echo '   {'
    echo '     "baseURL": "http://192.168.0.100:4000/v1",'
    echo '     "apiKey":  "sk-...",'
    echo '     "allowInsecureRequests": true,'
    echo '     "model": "gpt-5.4-nano"'
    echo '   }'
    echo ""
    echo "   See .github/skills/live-proxy-test/SKILL.md for full instructions."
    exit 0
fi

echo "✅ Proxy config found: $PROXY_CONFIG"

# ---------------------------------------------------------------------------
# resolve repo root via git (not a hard-coded path)
# ---------------------------------------------------------------------------
REPO_ROOT="$(git -C "$ORIGINAL_PWD" rev-parse --show-toplevel)"
echo "Repo root: $REPO_ROOT"

# ---------------------------------------------------------------------------
# scaffold temporary runner package
# ---------------------------------------------------------------------------
RUNNER="$(mktemp -d -t swiftopenai-live-test.XXXXXX)"
echo "Runner dir: $RUNNER"

cd "$RUNNER"
swift package init --type executable --name LiveTest >/dev/null 2>&1

# Write Package.swift with path-based dep on the local SwiftOpenAI checkout
cat > Package.swift <<PKGEOF
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LiveTest",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "${REPO_ROOT}")
    ],
    targets: [
        .executableTarget(
            name: "LiveTest",
            dependencies: [
                .product(name: "SwiftOpenAI", package: "swiftopenai")
            ]
        )
    ]
)
PKGEOF

# ---------------------------------------------------------------------------
# write main.swift — 11 scenarios
# ---------------------------------------------------------------------------
mkdir -p Sources/LiveTest
cat > Sources/LiveTest/main.swift <<'SWIFTEOF'
import Foundation
import SwiftOpenAI

// ---------------------------------------------------------------------------
// Proxy config loader
// ---------------------------------------------------------------------------
struct ProxyConfig: Codable, Sendable {
    let baseURL: String
    let apiKey: String
    let allowInsecureRequests: Bool
    let model: String
}

func loadConfig() throws -> ProxyConfig {
    let path = ProcessInfo.processInfo.environment["SWIFTOPENAI_LIVE_PROXY"]
        ?? "/tmp/pibochat-live-proxy.json"
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return try JSONDecoder().decode(ProxyConfig.self, from: data)
}

// ---------------------------------------------------------------------------
// Scenario result tracking
// ---------------------------------------------------------------------------
actor ScenarioResults {
    var results: [(Int, String, Bool, String)] = []  // (number, name, passed, detail)

    func record(number: Int, name: String, passed: Bool, detail: String) {
        results.append((number, name, passed, detail))
    }

    func allPassed() -> Bool {
        results.allSatisfy { $0.2 }
    }

    func printSummary() {
        print("\n## Live Proxy Test Summary")
        print("| # | Scenario | Result | Detail |")
        print("|---|---|---|---|")
        for (num, name, passed, detail) in results {
            let icon = passed ? "✅" : "❌"
            print("| \(num) | \(name) | \(icon) | \(detail) |")
        }
    }
}

// ---------------------------------------------------------------------------
// Main entry point
// ---------------------------------------------------------------------------
let cfg = try loadConfig()
let tracker = ScenarioResults()

let client = OpenAI(
    apiKey: cfg.apiKey,
    baseURL: URL(string: cfg.baseURL)!,
    allowInsecureRequests: cfg.allowInsecureRequests
)

print("## Live Proxy Test — SwiftOpenAI")
print("Proxy: \(cfg.baseURL)")
print("Model: \(cfg.model)")
print("")

// ---------------------------------------------------------------------------
// Scenario 1: Chat completion (non-streaming)
// ---------------------------------------------------------------------------
print("--- Scenario 1: Chat completion (non-streaming) ---")
do {
    let response = try await client.chat.completions.create(
        .init(
            model: cfg.model,
            messages: [.user("Reply with exactly the word: pong")]
        )
    )
    let text = response.choices.first?.message.content ?? ""
    let passed = !text.isEmpty
    let detail = "choices=\(response.choices.count) text='\(text.prefix(50))'"
    await tracker.record(number: 1, name: "Chat (non-streaming)", passed: passed, detail: detail)
    print("Result: \(passed ? "✅ PASS" : "❌ FAIL") — \(detail)")
} catch {
    await tracker.record(number: 1, name: "Chat (non-streaming)", passed: false, detail: "error: \(error)")
    print("Result: ❌ FAIL — \(error)")
}

// ---------------------------------------------------------------------------
// Scenario 2: Chat completion (streaming) — SSE iteration + EOF flush
// ---------------------------------------------------------------------------
print("\n--- Scenario 2: Chat completion (streaming) ---")
do {
    let stream = client.chat.completions.createStream(
        .init(
            model: cfg.model,
            messages: [.user("Count from 1 to 5, one number per word.")]
        )
    )
    var chunkCount = 0
    var textAccumulated = ""
    for try await chunk in stream {
        chunkCount += 1
        if let delta = chunk.choices.first?.delta.content {
            textAccumulated += delta
        }
    }
    let passed = chunkCount > 0
    let detail = "chunks=\(chunkCount) text='\(textAccumulated.prefix(60))'"
    await tracker.record(number: 2, name: "Chat (streaming)", passed: passed, detail: detail)
    print("Result: \(passed ? "✅ PASS" : "❌ FAIL") — \(detail)")
} catch {
    await tracker.record(number: 2, name: "Chat (streaming)", passed: false, detail: "error: \(error)")
    print("Result: ❌ FAIL — \(error)")
}

// ---------------------------------------------------------------------------
// Scenario 3: Chat with image input (URL)
// ---------------------------------------------------------------------------
print("\n--- Scenario 3: Chat with image input (URL) ---")
do {
    let imageURL = "https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/PNG_transparency_demonstration_1.png/240px-PNG_transparency_demonstration_1.png"
    let response = try await client.chat.completions.create(
        .init(
            model: cfg.model,
            messages: [
                .user(text: "Describe this image in one sentence.", imageURL: imageURL)
            ]
        )
    )
    let text = response.choices.first?.message.content ?? ""
    let passed = !text.isEmpty
    let detail = "text='\(text.prefix(80))'"
    await tracker.record(number: 3, name: "Chat image URL", passed: passed, detail: detail)
    print("Result: \(passed ? "✅ PASS" : "❌ FAIL") — \(detail)")
} catch {
    await tracker.record(number: 3, name: "Chat image URL", passed: false, detail: "error: \(error)")
    print("Result: ❌ FAIL — \(error)")
}

// ---------------------------------------------------------------------------
// Scenario 4: Chat with image input (base64)
// ---------------------------------------------------------------------------
print("\n--- Scenario 4: Chat with image input (base64) ---")
do {
    // 1x1 red pixel PNG
    let pngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI6QAAAABJRU5ErkJggg=="
    let pngData = Data(base64Encoded: pngBase64)!
    let response = try await client.chat.completions.create(
        .init(
            model: cfg.model,
            messages: [
                .user(text: "What color is this pixel?", imageData: pngData, mimeType: .png)
            ]
        )
    )
    let text = response.choices.first?.message.content ?? ""
    let passed = !text.isEmpty
    let detail = "text='\(text.prefix(80))'"
    await tracker.record(number: 4, name: "Chat image base64", passed: passed, detail: detail)
    print("Result: \(passed ? "✅ PASS" : "❌ FAIL") — \(detail)")
} catch {
    await tracker.record(number: 4, name: "Chat image base64", passed: false, detail: "error: \(error)")
    print("Result: ❌ FAIL — \(error)")
}

// ---------------------------------------------------------------------------
// Scenario 5: Chat with reasoningEffort
// ---------------------------------------------------------------------------
print("\n--- Scenario 5: Chat with reasoningEffort ---")
do {
    let response = try await client.chat.completions.create(
        .init(
            model: cfg.model,
            messages: [.user("What is 2 + 2?")],
            reasoningEffort: .medium
        )
    )
    let text = response.choices.first?.message.content ?? ""
    let passed = !text.isEmpty
    let detail = "text='\(text.prefix(80))'"
    await tracker.record(number: 5, name: "Chat reasoningEffort", passed: passed, detail: detail)
    print("Result: \(passed ? "✅ PASS" : "❌ FAIL") — \(detail)")
} catch {
    await tracker.record(number: 5, name: "Chat reasoningEffort", passed: false, detail: "error: \(error)")
    print("Result: ❌ FAIL — \(error)")
}

// ---------------------------------------------------------------------------
// Scenario 6: Chat with strict function tool
// ---------------------------------------------------------------------------
print("\n--- Scenario 6: Chat with strict tool ---")
do {
    let weatherTool = ChatCompletionTool.function(
        ChatCompletionToolFunction(
            name: "get_weather",
            description: "Get the current weather for a city",
            parameters: [
                "type": AnyCodable("object"),
                "properties": AnyCodable([
                    "city": AnyCodable(["type": AnyCodable("string")]),
                    "unit": AnyCodable([
                        "type": AnyCodable("string"),
                        "enum": AnyCodable(["celsius", "fahrenheit"])
                    ])
                ] as [String: AnyCodable]),
                "required": AnyCodable(["city", "unit"])
            ],
            strict: true
        )
    )
    let response = try await client.chat.completions.create(
        .init(
            model: cfg.model,
            messages: [.user("What's the temperature in Tokyo in celsius?")],
            tools: [weatherTool],
            toolChoice: .auto
        )
    )
    let toolCalls = response.choices.first?.message.toolCalls ?? []
    let passed = !toolCalls.isEmpty || !(response.choices.first?.message.content ?? "").isEmpty
    let detail = "toolCalls=\(toolCalls.count) finishReason=\(response.choices.first?.finishReason ?? "nil")"
    await tracker.record(number: 6, name: "Chat strict tool", passed: passed, detail: detail)
    print("Result: \(passed ? "✅ PASS" : "❌ FAIL") — \(detail)")
} catch {
    await tracker.record(number: 6, name: "Chat strict tool", passed: false, detail: "error: \(error)")
    print("Result: ❌ FAIL — \(error)")
}

// ---------------------------------------------------------------------------
// Scenario 7: Chat streaming with streamOptions.includeUsage
// ---------------------------------------------------------------------------
print("\n--- Scenario 7: Chat streaming with streamOptions.includeUsage ---")
do {
    let stream = client.chat.completions.createStream(
        .init(
            model: cfg.model,
            messages: [.user("Reply with exactly the word: pong")],
            streamOptions: ChatCompletionStreamOptions(includeUsage: true)
        )
    )
    var chunkCount = 0
    var usageFound = false
    for try await chunk in stream {
        chunkCount += 1
        if chunk.usage != nil {
            usageFound = true
        }
    }
    let passed = chunkCount > 0 && usageFound
    let detail = "chunks=\(chunkCount) usageChunkReceived=\(usageFound)"
    await tracker.record(number: 7, name: "Chat streaming includeUsage", passed: passed, detail: detail)
    print("Result: \(passed ? "✅ PASS" : "❌ FAIL") — \(detail)")
} catch {
    await tracker.record(number: 7, name: "Chat streaming includeUsage", passed: false, detail: "error: \(error)")
    print("Result: ❌ FAIL — \(error)")
}

// ---------------------------------------------------------------------------
// Scenario 8: Embeddings
// ---------------------------------------------------------------------------
print("\n--- Scenario 8: Embeddings ---")
do {
    let response = try await client.embeddings.create(
        model: "text-embedding-3-small",
        input: .string("Hello, SwiftOpenAI!")
    )
    let dims: Int
    switch response.data.first?.embedding {
    case .floats(let arr): dims = arr.count
    case .base64(let str): dims = str.count  // base64-encoded length (not float count, but >0 indicates success)
    case .none: dims = 0
    }
    let passed = dims > 0
    let detail = "embeddings=\(response.data.count) dims=\(dims)"
    await tracker.record(number: 8, name: "Embeddings", passed: passed, detail: detail)
    print("Result: \(passed ? "✅ PASS" : "❌ FAIL") — \(detail)")
} catch {
    await tracker.record(number: 8, name: "Embeddings", passed: false, detail: "error: \(error)")
    print("Result: ❌ FAIL — \(error)")
}

// ---------------------------------------------------------------------------
// Scenario 9: Responses (non-streaming)
// ---------------------------------------------------------------------------
print("\n--- Scenario 9: Responses (non-streaming) ---")
do {
    let response = try await client.responses.create(
        model: cfg.model,
        input: .string("Say hello in one word.")
    )
    let outputText = response.outputText
    let passed = !outputText.isEmpty || response.id != ""
    let detail = "id=\(response.id.prefix(20)) outputText='\(outputText.prefix(60))'"
    await tracker.record(number: 9, name: "Responses (non-streaming)", passed: passed, detail: detail)
    print("Result: \(passed ? "✅ PASS" : "❌ FAIL") — \(detail)")
} catch {
    await tracker.record(number: 9, name: "Responses (non-streaming)", passed: false, detail: "error: \(error)")
    print("Result: ❌ FAIL — \(error)")
}

// ---------------------------------------------------------------------------
// Scenario 10: Responses (streaming)
// ---------------------------------------------------------------------------
print("\n--- Scenario 10: Responses (streaming) ---")
do {
    let stream = client.responses.createStream(
        model: cfg.model,
        input: .string("Count: 1, 2, 3.")
    )
    var eventCount = 0
    for try await _ in stream {
        eventCount += 1
    }
    let passed = eventCount > 0
    let detail = "events=\(eventCount)"
    await tracker.record(number: 10, name: "Responses (streaming)", passed: passed, detail: detail)
    print("Result: \(passed ? "✅ PASS" : "❌ FAIL") — \(detail)")
} catch {
    await tracker.record(number: 10, name: "Responses (streaming)", passed: false, detail: "error: \(error)")
    print("Result: ❌ FAIL — \(error)")
}

// ---------------------------------------------------------------------------
// Scenario 11: Moderations
// ---------------------------------------------------------------------------
print("\n--- Scenario 11: Moderations ---")
do {
    let response = try await client.moderations.create(
        input: .string("I love building Swift SDKs!")
    )
    let flagged = response.results.first?.flagged ?? true
    let passed = true  // any response is a pass; flagged=false is expected for benign text
    let detail = "results=\(response.results.count) flagged=\(flagged)"
    await tracker.record(number: 11, name: "Moderations", passed: passed, detail: detail)
    print("Result: ✅ PASS — \(detail)")
} catch {
    await tracker.record(number: 11, name: "Moderations", passed: false, detail: "error: \(error)")
    print("Result: ❌ FAIL — \(error)")
}

// ---------------------------------------------------------------------------
// Final summary
// ---------------------------------------------------------------------------
await tracker.printSummary()

if await tracker.allPassed() {
    print("\n### Verdict: ✅ All 11 scenarios passed — ready for release")
    exit(0)
} else {
    print("\n### Verdict: ❌ One or more scenarios failed — review above")
    exit(1)
}
SWIFTEOF

# ---------------------------------------------------------------------------
# build and run
# ---------------------------------------------------------------------------
echo ""
echo "Building LiveTest runner…"
swift build 2>&1

echo ""
echo "Running 11 scenarios…"
echo ""
SWIFTOPENAI_LIVE_PROXY="$PROXY_CONFIG" swift run LiveTest 2>&1
RUN_EXIT=$?

# cleanup is handled by the trap
exit $RUN_EXIT
