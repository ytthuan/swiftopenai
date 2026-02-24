# SwiftOpenAI

A Swift port of the [OpenAI Python SDK](https://github.com/openai/openai-python) — providing async/await-based access to the full OpenAI API.

## Features

- **Full API coverage** — Chat Completions, Responses, Conversations, Embeddings, Images, Audio, Files, Fine-tuning, Models, Moderations, Batches, Uploads, Vector Stores
- **Swift 6 strict concurrency** — All types are `Sendable`, all APIs are `async throws`
- **All Apple platforms** — iOS 16+, macOS 13+, tvOS 16+, watchOS 9+, visionOS 1+
- **Zero dependencies** — Pure Swift, built on Foundation `URLSession`
- **Type-safe** — Codable request/response models with Swift enums

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ytthuan/swiftopenai.git", from: "0.1.0"),
]
```

Then add `"SwiftOpenAI"` to your target's dependencies.

## Quick Start

```swift
import SwiftOpenAI

let client = OpenAI(apiKey: "sk-...")
```

### Chat Completions

```swift
let response = try await client.chat.completions.create(
    model: "gpt-4o",
    messages: [
        .system("You are a helpful assistant."),
        .user("What is Swift concurrency?")
    ]
)
print(response.choices.first?.message.content ?? "")
```

### Streaming

```swift
let stream = try await client.chat.completions.createStream(
    model: "gpt-4o",
    messages: [.user("Tell me a story")]
)
for try await chunk in stream {
    if let content = chunk.choices.first?.delta.content {
        print(content, terminator: "")
    }
}
```

### Responses API

```swift
let response = try await client.responses.create(
    model: "gpt-4o",
    input: .text("Explain quantum computing")
)

// Multi-turn conversation with server-managed state
let followUp = try await client.responses.create(
    model: "gpt-4o",
    input: .text("Tell me more about qubits"),
    previousResponseId: response.id
)
```

### Conversations API

```swift
// Create a conversation with initial context
let conversation = try await client.conversations.create(
    items: [.system("You are a helpful tutor."), .user("Hello!")]
)

// Add items and list history
try await client.conversations.items.create(
    conversationId: conversation.id,
    items: [.assistant("Hi! How can I help?")]
)
let history = try await client.conversations.items.list(conversationId: conversation.id)
```

### Embeddings

```swift
let embeddings = try await client.embeddings.create(
    model: "text-embedding-3-small",
    input: .string("Hello world")
)
```

### Images

```swift
let images = try await client.images.generate(
    prompt: "A sunset over mountains",
    model: "dall-e-3"
)
```

### Audio

```swift
// Transcription
let text = try await client.audio.transcriptions.create(
    file: audioData, filename: "recording.mp3", model: "whisper-1"
)
// Text-to-Speech
let audio = try await client.audio.speech.create(
    model: "tts-1", input: "Hello!", voice: "alloy"
)
```

## API Reference

| Resource | Methods |
|----------|---------|
| `client.chat.completions` | `create()`, `createStream()` |
| `client.responses` | `create()`, `createStream()`, `retrieve()`, `delete()` |
| `client.embeddings` | `create()` |
| `client.images` | `generate()`, `edit()`, `createVariation()` |
| `client.audio.transcriptions` | `create()` |
| `client.audio.translations` | `create()` |
| `client.audio.speech` | `create()` |
| `client.files` | `create()`, `retrieve()`, `list()`, `delete()`, `content()` |
| `client.models` | `list()`, `retrieve()`, `delete()` |
| `client.moderations` | `create()` |
| `client.completions` | `create()` |
| `client.fineTuning.jobs` | `create()`, `retrieve()`, `list()`, `cancel()`, `listEvents()`, `listCheckpoints()` |
| `client.batches` | `create()`, `retrieve()`, `list()`, `cancel()` |
| `client.vectorStores` | `create()`, `retrieve()`, `update()`, `list()`, `delete()`, `search()` |
| `client.vectorStores.files` | `create()`, `retrieve()`, `list()`, `delete()` |
| `client.uploads` | `create()`, `cancel()`, `complete()` |
| `client.uploads.parts` | `create()` |

## Error Handling

```swift
do {
    let response = try await client.chat.completions.create(
        model: "gpt-4o", messages: [.user("Hello")]
    )
} catch let error as OpenAIError {
    switch error {
    case .authenticationError(let msg): print("Auth: \(msg)")
    case .rateLimitError(let msg): print("Rate limit: \(msg)")
    case .apiError(let code, let msg, _, _): print("\(code): \(msg)")
    default: print(error)
    }
}
```

## Examples

The [`Examples/`](Examples/) directory contains comprehensive, copy-paste-ready code for every feature:

| File | What's Inside |
|------|---------------|
| [`BasicUsage.swift`](Examples/BasicUsage.swift) | Models, Embeddings, Moderations, Images, Error handling |
| [`ChatExamples.swift`](Examples/ChatExamples.swift) | Simple chat, multi-turn conversation, streaming, tool calling, JSON mode |
| [`ResponsesExamples.swift`](Examples/ResponsesExamples.swift) | Responses API: text, `previousResponseId` conversations, Conversations API, streaming |
| [`AdvancedExamples.swift`](Examples/AdvancedExamples.swift) | Audio, Fine-tuning, Batches, Vector Stores, Uploads, Custom config |

## CI/CD

- **CI** — Every push/PR runs `swift build && swift test` on macOS and Linux via GitHub Actions
- **Release** — Tag with `v*` (e.g. `git tag v0.1.0 && git push --tags`) to auto-create a GitHub Release

## Project Status

🚧 **Work in progress** — Core API coverage is complete.

### Implemented
- ✅ Chat Completions (standard + streaming)
- ✅ Responses API (standard + streaming + `previousResponseId`)
- ✅ Conversations API (create, retrieve, update, delete, items)
- ✅ Embeddings, Images, Audio, Files, Models, Moderations
- ✅ Fine-tuning, Batches, Vector Stores, Uploads, Completions

### Not Yet Implemented
- ⬜ Realtime (WebSocket)
- ⬜ Beta resources (Assistants)

See [AGENTS.md](AGENTS.md) for architecture and contribution guidelines.

## License

MIT — See [LICENSE](LICENSE) for details.
