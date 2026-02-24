# SwiftOpenAI

A Swift port of the [OpenAI Python SDK](https://github.com/openai/openai-python) — providing async/await-based access to the full OpenAI API.

## Features

- **Full API coverage** — Chat Completions, Responses, Embeddings, Images, Audio, Files, Fine-tuning, Models, Moderations, Batches, Uploads, Vector Stores
- **Swift 6 strict concurrency** — All types are `Sendable`, all APIs are `async throws`
- **All Apple platforms** — iOS 16+, macOS 13+, tvOS 16+, watchOS 9+, visionOS 1+
- **Zero dependencies** — Pure Swift, built on Foundation `URLSession`
- **Type-safe** — Codable request/response models with Swift enums

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/swiftopenai.git", from: "0.1.0"),
]
```

Then add `"SwiftOpenAI"` to your target's dependencies.

## Quick Start

```swift
import SwiftOpenAI

let client = OpenAI(apiKey: "sk-...")

// Chat completion
let response = try await client.chat.completions.create(
    model: "gpt-4o",
    messages: [.user("Hello!")]
)
print(response.choices.first?.message.content ?? "")
```

## Project Status

🚧 **Work in progress** — Porting from the OpenAI Python SDK. See [AGENTS.md](AGENTS.md) for architecture details and contribution guidelines.

## License

MIT — See [LICENSE](LICENSE) for details.
