# SwiftOpenAI

A comprehensive Swift SDK for the [OpenAI API](https://platform.openai.com/docs/api-reference) — ported from the official [openai-python](https://github.com/openai/openai-python) SDK.

[![CI](https://github.com/ytthuan/swiftopenai/actions/workflows/ci.yml/badge.svg)](https://github.com/ytthuan/swiftopenai/actions/workflows/ci.yml)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-iOS%2016%2B%20%7C%20macOS%2013%2B%20%7C%20tvOS%2016%2B%20%7C%20watchOS%209%2B%20%7C%20visionOS%201%2B%20%7C%20Linux-lightgrey.svg)](https://swift.org)

## Features

- **Full API coverage** — Responses, Chat Completions, Conversations, Embeddings, Images, Audio, Files, Fine-tuning, Models, Moderations, Batches, Uploads, Vector Stores
- **Swift 6 strict concurrency** — All types are `Sendable`, all APIs are `async throws`
- **WebSocket mode** — Persistent connections for low-latency agentic workflows (up to ~40% faster)
- **Streaming** — Real-time `AsyncSequence`-based SSE streaming for both Chat and Responses APIs
- **Function calling & tools** — Full support for function calling, code interpreter, file search, and web search tools
- **Structured outputs** — JSON Schema-based structured output for deterministic response formats
- **All Apple platforms + Linux** — iOS 16+, macOS 13+, tvOS 16+, watchOS 9+, visionOS 1+, Linux (Swift 6.0)
- **Zero dependencies** — Pure Swift, built on Foundation `URLSession`
- **Type-safe** — Codable request/response models with Swift enums

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ytthuan/swiftopenai.git", from: "0.4.0"),
]
```

Then add `"SwiftOpenAI"` to your target's dependencies:

```swift
.target(name: "YourApp", dependencies: [
    .product(name: "SwiftOpenAI", package: "swiftopenai"),
]),
```

## Quick Start

```swift
import SwiftOpenAI

// Default: api.openai.com
let client = OpenAI(apiKey: "sk-...")

// Custom endpoint (Azure, local, etc.)
let client = OpenAI(
    apiKey: "your-api-key",
    baseURL: URL(string: "https://your-endpoint.openai.azure.com/openai/v1")!
)
```

---

## Responses API

The [Responses API](https://platform.openai.com/docs/api-reference/responses) is OpenAI's latest API for text generation, supporting tools, streaming, structured outputs, multi-turn conversations, and more.

### Basic Text Generation

```swift
let response = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("What is Swift concurrency?")
)
print(response.outputText ?? "")
```

> **Tip:** `response.outputText` is a convenience property that extracts the first text content from the output.

### With System Instructions

```swift
let response = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("Explain monads"),
    instructions: "You are a functional programming expert. Keep answers concise."
)
```

### Multi-turn Conversations (previousResponseId)

Chain responses together using `previousResponseId` — the server retains conversation context:

```swift
let r1 = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("My name is Alice and I'm building a Swift SDK."),
    store: true  // Required for server-side persistence
)

let r2 = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("What's my name and what am I building?"),
    previousResponseId: r1.id
)
print(r2.outputText ?? "")
// → "Your name is Alice and you're building a Swift SDK."
```

### Stateful Context with `store: true`

Use `store: true` to maintain state from turn to turn, preserving reasoning and tool context across interactions. Stored responses are persisted on the server for 30 days (or indefinitely when attached to a conversation).

```swift
// Turn 1: Define tools and make a function call — store the full context
let r1 = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("What's the weather in Paris?"),
    store: true,
    tools: [weatherTool]
)

// The model calls get_weather — provide the result
let fc = r1.output.first(where: { $0.type == "function_call" })!
let r2 = try await client.responses.create(
    model: "gpt-4.1",
    input: .items([
        .functionCallOutput(FunctionCallOutput(callId: fc.callId!, output: "{\"temp\": 18}"))
    ]),
    store: true,
    previousResponseId: r1.id,
    tools: [weatherTool]
)

// Turn 3: The model remembers the tool call and its result from prior turns
let r3 = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("Was it warm there?"),
    previousResponseId: r2.id  // Full tool context is preserved
)
print(r3.outputText ?? "")
// → The model remembers the weather was 18°C in Paris
```

> **Note:** Without `store: true`, the server does not persist context between turns. You would need to pass the full conversation history manually via `.items([...])`.

Streaming also supports stateful context:

```swift
let stream = try await client.responses.createStream(
    model: "gpt-4.1",
    input: .text("Tell me more about that."),
    store: true,
    previousResponseId: previousId
)
for try await event in stream {
    if let delta = event.delta { print(delta, terminator: "") }
}
```

### Multi-turn with Manual History

Pass conversation history directly as input items:

```swift
let response = try await client.responses.create(
    model: "gpt-4.1",
    input: .items([
        .message(ResponseInputMessage(role: "user", content: "My favorite color is blue.")),
        .message(ResponseInputMessage(role: "assistant", content: "Got it! Blue is a great color.")),
        .message(ResponseInputMessage(role: "user", content: "What is my favorite color?")),
    ])
)
```

### Store, Retrieve, and Delete

```swift
let created = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("Hello!"),
    store: true,
    metadata: ["session": "demo", "user": "alice"]
)

let retrieved = try await client.responses.retrieve(created.id)
let deleted = try await client.responses.delete(created.id)
print(deleted.deleted) // true
```

---

## Streaming (Responses API)

Stream responses in real-time using `AsyncSequence`:

### Text Streaming

```swift
let stream = try await client.responses.createStream(
    model: "gpt-4.1",
    input: .text("Write a poem about Swift.")
)

for try await event in stream {
    // event.type tells you what kind of event (e.g. "response.output_text.delta")
    if let delta = event.delta {
        print(delta, terminator: "")  // Print text chunks as they arrive
    }
}
print() // Newline at end
```

### Streaming with Instructions

```swift
let stream = try await client.responses.createStream(
    model: "gpt-4.1",
    input: .text("Explain recursion"),
    instructions: "Answer in exactly one sentence."
)

var fullText = ""
for try await event in stream {
    if let delta = event.delta {
        fullText += delta
    }
}
print(fullText)
```

### Streaming with Function Calls

When using tools with streaming, function call arguments arrive incrementally. Use the `response.completed` event to get the final response:

```swift
let tool = ResponseTool.function(FunctionToolDefinition(
    name: "get_weather",
    description: "Get current weather for a city.",
    parameters: [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "city": AnyCodable(["type": AnyCodable("string")] as [String: AnyCodable])
        ] as [String: AnyCodable]),
        "required": AnyCodable(["city"]),
        "additionalProperties": AnyCodable(false),
    ],
    strict: true
))

let stream = try await client.responses.createStream(
    model: "gpt-4.1",
    input: .text("What's the weather in Paris?"),
    tools: [tool]
)

for try await event in stream {
    switch event.type {
    case "response.output_text.delta":
        print(event.delta ?? "", terminator: "")
    case "response.function_call_arguments.delta":
        print("Args chunk: \(event.delta ?? "")")
    case "response.completed":
        if let response = event.response,
           let fc = response.output.first(where: { $0.type == "function_call" }) {
            print("Function: \(fc.name ?? "")(\(fc.arguments ?? ""))")
        }
    default:
        break
    }
}
```

### Stream Event Types

| Event Type | Description | Key Fields |
|-----------|-------------|------------|
| `response.created` | Stream started | `response` |
| `response.output_text.delta` | Text chunk arrived | `delta` |
| `response.output_text.done` | Text output complete | — |
| `response.function_call_arguments.delta` | Function args chunk | `delta` |
| `response.function_call_arguments.done` | Function args complete | — |
| `response.output_item.added` | New output item | `item`, `outputIndex` |
| `response.output_item.done` | Output item complete | `item` |
| `response.completed` | Full response ready | `response` |
| `response.failed` | Response failed | `response` |

---

## Function Calling (Responses API)

### Defining Tools

```swift
let weatherTool = ResponseTool.function(FunctionToolDefinition(
    name: "get_weather",
    description: "Get current weather for a city.",
    parameters: [
        "type": AnyCodable("object"),
        "properties": AnyCodable([
            "city": AnyCodable([
                "type": AnyCodable("string"),
                "description": AnyCodable("City name"),
            ] as [String: AnyCodable]),
            "unit": AnyCodable([
                "type": AnyCodable("string"),
                "enum": AnyCodable(["celsius", "fahrenheit"]),
            ] as [String: AnyCodable]),
        ] as [String: AnyCodable]),
        "required": AnyCodable(["city"]),
        "additionalProperties": AnyCodable(false),
    ],
    strict: true  // Enforces schema validation
))
```

> **Important:** When `strict: true`, every object in your schema **must** include `"additionalProperties": AnyCodable(false)`.

### Full Function Calling Round-Trip

```swift
// Step 1: Send request with tools
let r1 = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("What's the weather in Tokyo?"),
    tools: [weatherTool]
)

// Step 2: Check if the model wants to call a function
guard let fc = r1.output.first(where: { $0.type == "function_call" }),
      let callId = fc.callId,
      let name = fc.name,
      let args = fc.arguments else {
    print("No function call")
    return
}

print("Model called: \(name)(\(args))")
// → Model called: get_weather({"city":"Tokyo"})

// Step 3: Execute the function (your code) and return results
let weatherResult = "{\"temp\": 22, \"condition\": \"sunny\", \"unit\": \"celsius\"}"

let r2 = try await client.responses.create(
    model: "gpt-4.1",
    input: .items([
        .message(ResponseInputMessage(role: "user", content: "What's the weather in Tokyo?")),
        .functionCall(FunctionCallItem(callId: callId, name: name, arguments: args)),
        .functionCallOutput(FunctionCallOutput(callId: callId, output: weatherResult)),
    ]),
    tools: [weatherTool]
)

print(r2.outputText ?? "")
// → "The weather in Tokyo is 22°C and sunny."
```

### Tool Choice

Control which tools the model uses:

```swift
// Let the model decide (default)
toolChoice: .auto

// Force the model to use a tool
toolChoice: .required

// Force a specific function
toolChoice: .function("get_weather")

// Disable all tools
toolChoice: .disabled
```

### Multiple Tools

```swift
let tools: [ResponseTool] = [
    .function(FunctionToolDefinition(
        name: "get_weather",
        description: "Get weather for a city",
        parameters: weatherSchema,
        strict: true
    )),
    .function(FunctionToolDefinition(
        name: "calculate",
        description: "Evaluate a math expression",
        parameters: calcSchema,
        strict: true
    )),
]

let response = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("What's 15°C in Fahrenheit? Use the calculate tool."),
    tools: tools,
    toolChoice: .required  // Force tool usage
)
```

### Built-in Tools

```swift
// Web search
.webSearch(WebSearchToolDefinition())

// Code interpreter
.codeInterpreter(CodeInterpreterToolDefinition(container: "container-id"))

// File search (vector store)
.fileSearch(FileSearchToolDefinition(vectorStoreIds: ["vs_abc123"]))
```

---

## Structured Outputs (JSON Schema)

Force the model to return JSON matching a specific schema:

```swift
let schema: [String: AnyCodable] = [
    "type": AnyCodable("object"),
    "properties": AnyCodable([
        "name": AnyCodable(["type": AnyCodable("string")] as [String: AnyCodable]),
        "population": AnyCodable(["type": AnyCodable("number")] as [String: AnyCodable]),
        "capital": AnyCodable(["type": AnyCodable("string")] as [String: AnyCodable]),
    ] as [String: AnyCodable]),
    "required": AnyCodable(["name", "population", "capital"]),
    "additionalProperties": AnyCodable(false),
]

let response = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("Give me info about France."),
    text: ResponseTextConfig(format: .jsonSchema(ResponseTextFormatJSONSchema(
        name: "country_info",
        schema: schema,
        strict: true
    )))
)

let json = response.outputText ?? "{}"
print(json)
// → {"name":"France","population":67390000,"capital":"Paris"}
```

---

## Compaction

Reduce token usage in long conversations:

### Automatic (Server-Side)

```swift
let response = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("Continue our discussion..."),
    previousResponseId: previousId,
    contextManagement: [ContextManagement(compactThreshold: 5000)]
)
```

### Manual (Standalone Endpoint)

```swift
let compacted = try await client.responses.compact(
    model: "gpt-4.1",
    previousResponseId: longConversationId
)
print("Tokens used: \(compacted.usage?.inputTokens ?? 0) in, \(compacted.usage?.outputTokens ?? 0) out")
```

---

## WebSocket Mode *(New in v0.3.0)*

Use persistent WebSocket connections for lower-latency agentic workflows. WebSocket mode keeps a connection open to `/v1/responses` and sends only incremental input per turn, reducing per-turn overhead by up to **~40%** for tool-call-heavy workflows.

> **Note:** WebSocket mode is Apple-only (macOS 13+, iOS 16+). Requires `URLSessionWebSocketTask`.

### Basic Usage

```swift
let ws = client.responses.connectWebSocket()
await ws.connect()

let stream = try await ws.create(
    model: "gpt-5.2",
    input: .text("Explain quantum computing briefly."),
    store: false
)

for try await event in stream {
    if let delta = event.delta { print(delta, terminator: "") }
}

await ws.close()
```

### Multi-Turn (Incremental Input)

Continue a conversation by sending only new input plus `previousResponseId`:

```swift
let ws = client.responses.connectWebSocket()
await ws.connect()

// Turn 1
let stream1 = try await ws.create(model: "gpt-5.2", input: .text("My name is Alice."), store: false)
var responseId: String?
for try await event in stream1 {
    if event.type == "response.completed" { responseId = event.response?.id }
}

// Turn 2 — only sends new input, server reuses connection-local context
let stream2 = try await ws.create(
    model: "gpt-5.2",
    input: .text("What's my name?"),
    previousResponseId: responseId,
    store: false
)
for try await event in stream2 {
    if let delta = event.delta { print(delta, terminator: "") }
}

await ws.close()
```

### Function Calling over WebSocket

```swift
let ws = client.responses.connectWebSocket()
await ws.connect()

let stream1 = try await ws.create(
    model: "gpt-5.2",
    input: .text("What's the weather in Tokyo?"),
    tools: [weatherTool],
    store: false
)

var callId: String?
var responseId: String?
for try await event in stream1 {
    if event.type == "response.completed" {
        responseId = event.response?.id
        if let fc = event.response?.output.first(where: { $0.type == "function_call" }) {
            callId = fc.callId
        }
    }
}

// Provide tool result — only incremental input, low latency
let stream2 = try await ws.create(
    model: "gpt-5.2",
    input: .items([
        .functionCallOutput(FunctionCallOutput(callId: callId!, output: "{\"temp\": 22}"))
    ]),
    previousResponseId: responseId,
    tools: [weatherTool],
    store: false
)
for try await event in stream2 {
    if let delta = event.delta { print(delta, terminator: "") }
}

await ws.close()
```

### Warmup (Pre-warm State)

Pre-warm request state for even faster first response:

```swift
let ws = client.responses.connectWebSocket()
await ws.connect()

// Warmup — no model output, but prepares state
let warmupId = try await ws.warmup(
    model: "gpt-5.2",
    input: .text("System ready."),
    tools: [tool1, tool2]
)

// First real turn — faster because state was pre-warmed
let stream = try await ws.create(
    model: "gpt-5.2",
    input: .text("Run the analysis."),
    previousResponseId: warmupId,
    tools: [tool1, tool2],
    store: false
)
```

### Key Behaviors
- **Sequential execution** — one response at a time per connection
- **60-minute limit** — reconnect when the limit is reached
- **ZDR compatible** — works with `store: false` and Zero Data Retention
- **Connection-local cache** — the most recent response is cached in memory for fast continuation

---

## Conversations API

Server-managed conversation state that persists across sessions:

```swift
// Create a conversation
let conv = try await client.conversations.create(
    items: [.system("You are a helpful tutor.")],
    metadata: ["topic": "math"]
)

// Use conversation with Responses API
let r1 = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("What is calculus?"),
    conversation: conv.id
)

// Continue in same conversation — context is retained
let r2 = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("Give me an example of a derivative."),
    conversation: conv.id
)

// Manage items
let items = try await client.conversations.items.list(conversationId: conv.id)
let item = try await client.conversations.items.retrieve("item_abc", conversationId: conv.id)

// Update metadata
try await client.conversations.update(conv.id, metadata: ["status": "completed"])

// Delete when done
try await client.conversations.delete(conv.id)
```

---

## Chat Completions API

The [Chat Completions API](https://platform.openai.com/docs/api-reference/chat) for conversational text generation:

### Basic Chat

```swift
let response = try await client.chat.completions.create(
    model: "gpt-4.1",
    messages: [
        .system("You are a helpful assistant."),
        .user("What is the capital of France?"),
    ]
)
print(response.choices.first?.message.content ?? "")
```

### Multi-turn Chat

```swift
var messages: [ChatCompletionMessage] = [
    .system("You are a geography tutor."),
    .user("What continent is Brazil in?"),
]

let r1 = try await client.chat.completions.create(model: "gpt-4.1", messages: messages)
let reply = r1.choices.first?.message.content ?? ""

messages.append(.assistant(reply))
messages.append(.user("What is its capital?"))

let r2 = try await client.chat.completions.create(model: "gpt-4.1", messages: messages)
```

### Chat Streaming

```swift
let stream = try await client.chat.completions.createStream(
    model: "gpt-4.1",
    messages: [.user("Tell me a story")]
)
for try await chunk in stream {
    if let content = chunk.choices.first?.delta?.content {
        print(content, terminator: "")
    }
}
```

### Chat Function Calling

```swift
let tool = ChatCompletionTool(
    function: ChatCompletionToolFunction(
        name: "get_weather",
        description: "Get current weather",
        parameters: [
            "type": AnyCodable("object"),
            "properties": AnyCodable([
                "city": AnyCodable(["type": AnyCodable("string")] as [String: AnyCodable])
            ] as [String: AnyCodable]),
            "required": AnyCodable(["city"]),
            "additionalProperties": AnyCodable(false),
        ]
    )
)

let r1 = try await client.chat.completions.create(
    model: "gpt-4.1",
    messages: [.user("Weather in London?")],
    tools: [tool]
)

if let toolCall = r1.choices.first?.message.toolCalls?.first {
    // Execute tool, then continue:
    let r2 = try await client.chat.completions.create(
        model: "gpt-4.1",
        messages: [
            .user("Weather in London?"),
            .assistant("", toolCalls: [toolCall]),
            .tool("{\"temp\": 12}", toolCallId: toolCall.id),
        ],
        tools: [tool]
    )
}
```

### JSON Mode

```swift
let response = try await client.chat.completions.create(
    model: "gpt-4.1",
    messages: [
        .system("Respond in JSON."),
        .user("Return: {\"answer\": 42}"),
    ],
    responseFormat: .jsonObject
)
```

---

## Other APIs

### Embeddings

```swift
let response = try await client.embeddings.create(
    model: "text-embedding-3-small",
    input: .string("Hello world")
)
let dimensions = response.data.first?.embedding.count ?? 0

// Batch embeddings
let batch = try await client.embeddings.create(
    model: "text-embedding-3-small",
    input: .strings(["Hello", "World"])
)
```

### Models

```swift
let models = try await client.models.list()
let model = try await client.models.retrieve("gpt-4.1")
```

### Files

```swift
let files = try await client.files.list()
let file = try await client.files.create(
    file: data, filename: "training.jsonl", purpose: "fine-tune"
)
let content = try await client.files.content(file.id)
try await client.files.delete(file.id)
```

### Images

```swift
let images = try await client.images.generate(
    prompt: "A sunset over mountains",
    model: "dall-e-3",
    size: "1024x1024"
)
```

### Audio

```swift
// Speech to text
let transcription = try await client.audio.transcriptions.create(
    file: audioData, filename: "recording.mp3", model: "whisper-1"
)

// Text to speech
let audioData = try await client.audio.speech.create(
    model: "tts-1", input: "Hello world!", voice: "alloy"
)
```

### Moderations

```swift
let result = try await client.moderations.create(
    input: .string("Check this text for policy violations")
)
```

---

## API Reference

| Resource | Methods |
|----------|---------|
| `client.responses` | `create()`, `createStream()`, `retrieve()`, `delete()`, `compact()` |
| `client.chat.completions` | `create()`, `createStream()` |
| `client.conversations` | `create()`, `retrieve()`, `update()`, `delete()` |
| `client.conversations.items` | `create()`, `list()`, `retrieve()`, `delete()` |
| `client.embeddings` | `create()` |
| `client.models` | `list()`, `retrieve()`, `delete()` |
| `client.files` | `create()`, `retrieve()`, `list()`, `delete()`, `content()` |
| `client.images` | `generate()`, `edit()`, `createVariation()` |
| `client.audio.transcriptions` | `create()` |
| `client.audio.translations` | `create()` |
| `client.audio.speech` | `create()` |
| `client.moderations` | `create()` |
| `client.fineTuning.jobs` | `create()`, `retrieve()`, `list()`, `cancel()`, `listEvents()` |
| `client.batches` | `create()`, `retrieve()`, `list()`, `cancel()` |
| `client.vectorStores` | `create()`, `retrieve()`, `update()`, `list()`, `delete()` |
| `client.vectorStores.files` | `create()`, `retrieve()`, `list()`, `delete()` |
| `client.uploads` | `create()`, `cancel()`, `complete()` |
| `client.uploads.parts` | `create()` |
| `client.completions` | `create()` (legacy) |

## Error Handling

All API methods throw `OpenAIError`:

```swift
do {
    let response = try await client.responses.create(
        model: "gpt-4.1", input: .text("Hello")
    )
} catch let error as OpenAIError {
    switch error {
    case .authenticationError(let msg):
        print("Auth failed: \(msg)")
    case .rateLimitError(let msg):
        print("Rate limited: \(msg)")
    case .apiError(let code, let msg, _, _):
        print("API error \(code): \(msg)")
    case .notFoundError(let msg):
        print("Not found: \(msg)")
    default:
        print("Error: \(error)")
    }
}
```

## Configuration

```swift
let client = OpenAI(
    apiKey: "sk-...",
    organization: "org-...",       // Optional
    project: "proj-...",           // Optional
    baseURL: URL(string: "https://your-endpoint.com/v1")!,
    timeoutInterval: 300           // Seconds (default: 600)
)
```

## Examples

The [`Examples/`](Examples/) directory contains copy-paste-ready code:

| File | What's Inside |
|------|---------------|
| [`BasicUsage.swift`](Examples/BasicUsage.swift) | Models, Embeddings, Moderations, Images, Error handling |
| [`ChatExamples.swift`](Examples/ChatExamples.swift) | Chat, multi-turn, streaming, tool calling, JSON mode |
| [`ResponsesExamples.swift`](Examples/ResponsesExamples.swift) | Responses API, streaming, conversations, tools |
| [`AdvancedExamples.swift`](Examples/AdvancedExamples.swift) | Audio, Fine-tuning, Batches, Vector Stores, Uploads |

## Project Status

| Feature | Status |
|---------|--------|
| Responses API (text, streaming, tools, structured outputs, compaction) | ✅ |
| Chat Completions (standard + streaming + tools) | ✅ |
| Conversations API (CRUD + items) | ✅ |
| Function calling (Responses + Chat) | ✅ |
| Structured outputs (JSON Schema) | ✅ |
| Embeddings, Images, Audio, Files, Models, Moderations | ✅ |
| Fine-tuning, Batches, Vector Stores, Uploads | ✅ |
| WebSocket Mode | ✅ |

## CI/CD

- **CI** — Every push/PR runs `swift build && swift test` on macOS 15 and Linux (Swift 6.0)
- **Release** — Tag with `v*` (e.g. `git tag v0.2.0 && git push --tags`) to auto-create a GitHub Release

## License

MIT — See [LICENSE](LICENSE) for details.
