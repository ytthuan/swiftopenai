# SwiftOpenAI

[![CI](https://github.com/ytthuan/swiftopenai/actions/workflows/ci.yml/badge.svg)](https://github.com/ytthuan/swiftopenai/actions/workflows/ci.yml)
![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2016%2B%20%7C%20macOS%2013%2B%20%7C%20tvOS%2016%2B%20%7C%20watchOS%209%2B%20%7C%20visionOS%201%2B%20%7C%20Linux-blue.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A comprehensive, pure Swift SDK for the [OpenAI API](https://platform.openai.com/docs/api-reference) — ported from the official [openai-python](https://github.com/openai/openai-python) SDK with zero dependencies.

---

## Features

- **Full API coverage** — Responses, Chat Completions, Embeddings, Images, Audio, Files, Fine-tuning, Batches, Vector Stores, Uploads, Moderations, Models, Conversations, Realtime, and Legacy Completions
- **Async/await** — every network call uses Swift concurrency; no completion handlers
- **Streaming** — `AsyncSequence`-based SSE streaming for Responses and Chat Completions
- **WebSocket mode** — persistent connection for Responses API with warmup support (Darwin only)
- **Realtime API** — full-duplex text and audio sessions via WebSocket (Darwin only)
- **Conversations API** — first-class multi-turn conversation management
- **Function calling** — define tools, handle round-trips, with built-in web search, code interpreter, and file search
- **Structured outputs** — JSON Schema enforcement for reliable extraction
- **Reasoning models** — `ReasoningConfig` for o-series models with configurable effort
- **Context compaction** — automatic and manual context management for long conversations
- **Swift 6 strict concurrency** — all public types are `Sendable`; zero data races
- **Zero dependencies** — only `Foundation`; no third-party packages
- **Cross-platform** — all Apple platforms + Linux (via `FoundationNetworking`)
- **Automatic retries** — exponential backoff with jitter on 429/5xx, `Retry-After` header support
- **Security hardened** — TLS 1.2+ enforcement, header injection prevention, path traversal protection, 10 MB buffer limits

---

## Installation

Add SwiftOpenAI to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ytthuan/swiftopenai.git", from: "0.6.0")
]
```

Then add the dependency to your target:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "SwiftOpenAI", package: "swiftopenai")
    ]
)
```

> **Note:** Requires Swift 6.0+ and swift-tools-version 6.0.

---

## Quick Start

```swift
import SwiftOpenAI

let client = OpenAI(apiKey: "sk-...")

let response = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("What is Swift concurrency?")
)

print(response.outputText ?? "")
// → Swift concurrency is a set of language features...
```

---

## Configuration

The `OpenAI` client accepts the following parameters:

```swift
let client = OpenAI(
    apiKey: "sk-...",
    organization: "org-...",                                      // Optional
    project: "proj-...",                                          // Optional
    baseURL: URL(string: "https://api.openai.com/v1")!,          // Default
    timeoutInterval: 600,                                         // Default: 600s
    maxRetries: 2,                                                // Default: 2 retries on 429/5xx
    retryDelay: 0.5,                                              // Default: 0.5s base for exponential backoff
    session: nil                                                  // Optional custom URLSession
)
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `apiKey` | `String` | *required* | Your OpenAI API key |
| `organization` | `String?` | `nil` | Organization ID for multi-org accounts |
| `project` | `String?` | `nil` | Project ID for scoped access |
| `baseURL` | `URL` | `https://api.openai.com/v1` | API base URL (for proxies or Azure) |
| `timeoutInterval` | `TimeInterval` | `600` | Request timeout in seconds |
| `maxRetries` | `Int` | `2` | Max retry attempts on 429/5xx (set 0 to disable) |
| `retryDelay` | `TimeInterval` | `0.5` | Base delay for exponential backoff |
| `session` | `URLSession?` | `nil` | Custom URLSession (SDK creates one if nil) |

### Connection Pre-warming

Pre-warm the TCP/TLS handshake for faster first requests:

```swift
import SwiftOpenAI

let client = OpenAI(apiKey: "sk-...")
try await client.warmConnection()

// Subsequent requests skip the handshake overhead
let response = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("Hello!")
)
```

### Shutdown

Invalidate and cancel the underlying URLSession when done:

```swift
client.shutdown()
```

### Azure OpenAI

SwiftOpenAI supports Azure OpenAI with two deployment options:

#### Option 1: Azure OpenAI Compatibility Endpoint (API Key)

Uses the resource-level v1 GA endpoint with API key authentication. Supports Chat Completions, Responses, Embeddings, Images, Audio, and other standard OpenAI APIs. **Does not support the Conversations API** (use Option 2 for conversations).

```swift
let client = OpenAI.azure(
    resourceName: "my-resource",       // Your Azure resource name
    apiKey: "your-azure-api-key"
)

// Chat Completions
let chatResponse = try await client.chat.completions.create(
    model: "gpt-4.1",
    messages: [.user(content: .text("Hello!"))]
)

// Responses API (multi-turn via previousResponseId)
let response = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("Hello!")
)
let followUp = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("Tell me more"),
    previousResponseId: response.id
)

// Streaming
let stream = try await client.responses.createStream(
    model: "gpt-4.1",
    input: .text("Write a poem about Swift")
)
for try await event in stream {
    if let delta = event.delta {
        print(delta, terminator: "")
    }
}
```

The endpoint URL follows the pattern: `https://{resource}.openai.azure.com/openai/v1`

#### Option 2: Azure AI Foundry Project Endpoint (Entra ID)

Uses the Foundry project endpoint with Azure Entra ID (OAuth 2.0 client credentials) authentication. **Supports ALL OpenAI APIs including the Conversations API** — the only way to use server-managed conversations on Azure.

**Prerequisites:**
1. An Azure AI Foundry project with a deployed model
2. An Azure Entra ID app registration with:
   - **Client ID** and **Client Secret** from the app registration
   - **Tenant ID** from your Azure AD directory
   - The **Azure AI Developer** role assigned to the app registration on the Foundry resource/project

```swift
let client = OpenAI.azureFoundry(
    endpoint: "https://myresource.services.ai.azure.com/api/projects/myproject",
    tenantId: "your-tenant-id",
    clientId: "your-client-id",
    clientSecret: "your-client-secret"
)
```

The SDK automatically:
- Obtains Entra ID tokens via OAuth 2.0 client credentials flow
- Caches tokens (~1 hour lifetime)
- Refreshes tokens 5 minutes before expiry
- Appends `api-version=2025-11-15-preview` to every request

**Conversations + Responses (multi-turn with server state):**

```swift
// Create a conversation — server manages the context
let conv = try await client.conversations.create()

// First turn — streamed
let stream1 = try await client.responses.createStream(
    model: "gpt-4.1",
    input: .text("I'm learning Swift concurrency."),
    conversation: conv.id
)
for try await event in stream1 {
    if let delta = event.delta { print(delta, terminator: "") }
}
print()

// Second turn — context is preserved by the server
let stream2 = try await client.responses.createStream(
    model: "gpt-4.1",
    input: .text("What should I learn first?"),
    conversation: conv.id
)
for try await event in stream2 {
    if let delta = event.delta { print(delta, terminator: "") }
}
```

**Manage conversation items:**

```swift
// List items in the conversation
let items = try await client.conversations.items.list(conversationId: conv.id)
for item in items.data {
    print("\(item.role ?? ""): \(item.content?.first?.text ?? "")")
}

// Add items to a conversation
try await client.conversations.items.create(
    conversationId: conv.id,
    items: [.system(content: "You are a Swift expert")]
)

// Conversation lifecycle
let retrieved = try await client.conversations.retrieve(conv.id)
let updated = try await client.conversations.update(conv.id, metadata: ["topic": "swift"])
let deleted = try await client.conversations.delete(conv.id)
```

**Pre-obtained token (e.g., from `az account get-access-token`):**

```swift
let client = OpenAI.azureFoundry(
    endpoint: "https://myresource.services.ai.azure.com/api/projects/myproject",
    token: "eyJ0eXAi..."  // Note: will NOT auto-refresh
)
```

**Custom API version:**

```swift
let client = OpenAI.azureFoundry(
    endpoint: "https://myresource.services.ai.azure.com/api/projects/myproject",
    tenantId: "...", clientId: "...", clientSecret: "...",
    apiVersion: "2024-10-21"  // Default: 2025-11-15-preview
)
```

#### Azure Feature Comparison

| Feature | Option 1 (API Key) | Option 2 (Foundry + Entra ID) |
|---------|:------------------:|:-----------------------------:|
| Chat Completions | ✅ | ✅ |
| Responses API | ✅ | ✅ |
| Streaming | ✅ | ✅ |
| Embeddings | ✅ | ✅ |
| Images / Audio | ✅ | ✅ |
| **Conversations API** | ❌ | ✅ |
| Token auto-refresh | N/A | ✅ |
| API key auth | ✅ | ❌ (Entra ID) |
| Multi-turn (chaining) | `previousResponseId` | `conversation` param |

#### Interactive Chat Console

The ExampleApp includes an interactive streaming chat console:

```bash
cd ExampleApp
swift run ExampleApp chat
```

Select backend 1 (API key) or 2 (Azure Foundry), then chat with streaming responses. Supports `/new`, `/system`, `/model`, `/info`, and `/quit` commands.

---

## Responses API

The Responses API is the primary interface for text generation.

### Basic Text Generation

```swift
import SwiftOpenAI

let client = OpenAI(apiKey: "sk-...")

let response = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("Explain quantum computing in one paragraph.")
)

// Use the outputText convenience property
print(response.outputText ?? "")
```

### System Instructions

```swift
let response = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("What should I cook tonight?"),
    instructions: "You are a helpful chef. Suggest meals using common pantry ingredients."
)

print(response.outputText ?? "")
```

### Multi-turn with `previousResponseId`

Chain responses together — the API manages context automatically:

```swift
let first = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("My name is Alice."),
    store: true
)

let second = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("What's my name?"),
    previousResponseId: first.id
)

print(second.outputText ?? "")
// → Your name is Alice.
```

### Multi-turn with Manual History

Build conversations by passing previous items:

```swift
let first = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("Remember: the secret code is 42.")
)

// Extract items from first response and append new input
var items: [ResponseInputItem] = first.output.map { .itemReference(ItemReference(id: $0.id ?? "")) }
items.append(.message(ResponseInputMessage(role: "user", content: .text("What was the secret code?"))))

let second = try await client.responses.create(
    model: "gpt-4.1",
    input: .items(items)
)

print(second.outputText ?? "")
// → The secret code is 42.
```

### Store, Retrieve, Delete

```swift
// Create a stored response
let response = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("Hello!"),
    store: true
)

// Retrieve it later
let retrieved = try await client.responses.retrieve(response.id)
print(retrieved.outputText ?? "")

// Delete when no longer needed
let deleted = try await client.responses.delete(response.id)
print(deleted.deleted)
// → true
```

### Metadata

Attach key-value metadata to responses:

```swift
let response = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("Summarize this document."),
    metadata: ["user_id": "u_123", "session": "onboarding"]
)
```

---

## Streaming (Responses API)

### Text Streaming

```swift
import SwiftOpenAI

let client = OpenAI(apiKey: "sk-...")

let stream = try await client.responses.createStream(
    model: "gpt-4.1",
    input: .text("Write a haiku about Swift.")
)

for try await event in stream {
    if event.type == "response.output_text.delta", let delta = event.delta {
        print(delta, terminator: "")
    }
}
print() // newline
```

### Streaming with Instructions

```swift
let stream = try await client.responses.createStream(
    model: "gpt-4.1",
    input: .text("What are closures?"),
    instructions: "Explain like I'm five."
)

for try await event in stream {
    if event.type == "response.output_text.delta", let delta = event.delta {
        print(delta, terminator: "")
    }
}
```

### Streaming with Function Calls

```swift
let tools: [ResponseTool] = [
    .function(FunctionToolDefinition(
        name: "get_weather",
        description: "Get weather for a location",
        parameters: ["type": "object", "properties": ["location": ["type": "string"]], "required": ["location"]]
    ))
]

let stream = try await client.responses.createStream(
    model: "gpt-4.1",
    input: .text("What's the weather in Tokyo?"),
    tools: tools
)

var functionArgs = ""
var functionCallId = ""

for try await event in stream {
    switch event.type {
    case "response.function_call_arguments.delta":
        functionArgs += event.delta ?? ""
    case "response.function_call_arguments.done":
        functionCallId = event.callId ?? ""
        print("Function call: get_weather(\(functionArgs))")
    default:
        break
    }
}
```

### Event Type Reference

<details>
<summary>Expand event types</summary>

| Event Type | Description |
|-----------|-------------|
| `response.created` | Response object created |
| `response.in_progress` | Generation started |
| `response.completed` | Generation finished |
| `response.failed` | Generation failed |
| `response.incomplete` | Generation stopped early |
| `response.output_item.added` | New output item started |
| `response.output_item.done` | Output item finished |
| `response.content_part.added` | Content part started |
| `response.content_part.done` | Content part finished |
| `response.output_text.delta` | Text token delta |
| `response.output_text.done` | Full text output done |
| `response.function_call_arguments.delta` | Function argument delta |
| `response.function_call_arguments.done` | Function arguments complete |
| `response.reasoning_summary_text.delta` | Reasoning summary delta |
| `response.reasoning_summary_text.done` | Reasoning summary done |

</details>

---

## Function Calling (Responses API)

### Define Tools and Handle Round-trips

```swift
import SwiftOpenAI

let client = OpenAI(apiKey: "sk-...")

// 1. Define a function tool
let tools: [ResponseTool] = [
    .function(FunctionToolDefinition(
        name: "get_weather",
        description: "Get current weather for a city",
        parameters: [
            "type": "object",
            "properties": [
                "city": ["type": "string", "description": "City name"]
            ],
            "required": ["city"]
        ]
    ))
]

// 2. Send the request
let response = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("What's the weather in Paris?"),
    tools: tools
)

// 3. Check for function calls in the output
for item in response.output {
    if item.type == "function_call", let name = item.name, let args = item.arguments {
        print("Call: \(name)(\(args))")
        // → Call: get_weather({"city":"Paris"})

        // 4. Execute the function and return result
        let result = try await client.responses.create(
            model: "gpt-4.1",
            input: .items([
                .itemReference(ItemReference(id: item.id ?? "")),
                .functionCallOutput(FunctionCallOutput(
                    callId: item.callId ?? "",
                    output: "{\"temp\": \"18°C\", \"condition\": \"Cloudy\"}"
                ))
            ]),
            tools: tools
        )

        print(result.outputText ?? "")
        // → The weather in Paris is 18°C and cloudy.
    }
}
```

### Tool Choice Options

```swift
// Let the model decide (default)
toolChoice: .auto

// Force the model to call a tool
toolChoice: .required

// Disable tool use
toolChoice: .disabled

// Force a specific function
toolChoice: .function("get_weather")
```

### Multiple Tools

```swift
let tools: [ResponseTool] = [
    .function(FunctionToolDefinition(
        name: "get_weather",
        description: "Get current weather",
        parameters: ["type": "object", "properties": ["city": ["type": "string"]], "required": ["city"]]
    )),
    .function(FunctionToolDefinition(
        name: "get_time",
        description: "Get current time in a timezone",
        parameters: ["type": "object", "properties": ["timezone": ["type": "string"]], "required": ["timezone"]]
    ))
]

let response = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("What's the weather and time in London?"),
    tools: tools,
    parallelToolCalls: true  // Allow multiple simultaneous calls
)
```

### Built-in Tools

```swift
// Web Search
let response = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("What happened in tech news today?"),
    tools: [.webSearch(WebSearchToolDefinition())]
)

// Code Interpreter
let response = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("Calculate the standard deviation of [4, 8, 15, 16, 23, 42]"),
    tools: [.codeInterpreter(CodeInterpreterToolDefinition())]
)

// File Search (requires a vector store)
let response = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("Find references to authentication in the docs"),
    tools: [.fileSearch(FileSearchToolDefinition(vectorStoreIds: ["vs_abc123"]))]
)
```

---

## Structured Outputs

Enforce a JSON Schema on model output:

```swift
import SwiftOpenAI

let client = OpenAI(apiKey: "sk-...")

let schema: [String: AnyCodable] = [
    "type": "object",
    "properties": [
        "name": ["type": "string"],
        "age": ["type": "integer"],
        "hobbies": [
            "type": "array",
            "items": ["type": "string"]
        ]
    ],
    "required": ["name", "age", "hobbies"],
    "additionalProperties": false
]

let response = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("Generate a profile for a fictional character."),
    text: ResponseTextConfig(format: .jsonSchema(ResponseTextFormatJSONSchema(
        name: "character_profile",
        schema: schema,
        strict: true
    )))
)

print(response.outputText ?? "")
// → {"name":"Elena Voss","age":34,"hobbies":["rock climbing","astrophotography","cooking"]}
```

---

## Reasoning

Use o-series models with configurable reasoning effort:

```swift
import SwiftOpenAI

let client = OpenAI(apiKey: "sk-...")

let response = try await client.responses.create(
    model: "o3",
    input: .text("What is the sum of the first 50 prime numbers?"),
    reasoning: ReasoningConfig(effort: "high")  // "low", "medium", "high"
)

print(response.outputText ?? "")

// Access reasoning token usage
if let details = response.usage?.outputTokensDetails {
    print("Reasoning tokens: \(details.reasoningTokens ?? 0)")
}
```

### Streaming with Reasoning

```swift
let stream = try await client.responses.createStream(
    model: "o3",
    input: .text("Prove that √2 is irrational."),
    reasoning: ReasoningConfig(effort: "high")
)

for try await event in stream {
    switch event.type {
    case "response.reasoning_summary_text.delta":
        print("[reasoning] \(event.delta ?? "")", terminator: "")
    case "response.output_text.delta":
        print(event.delta ?? "", terminator: "")
    default:
        break
    }
}
```

---

## Compaction

Manage long conversations by compacting context.

### Automatic Compaction

```swift
let response = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("Continue our discussion..."),
    previousResponseId: previousId,
    contextManagement: ContextManagement(
        type: "compaction",
        compactThreshold: 10000  // Compact when context exceeds this many tokens
    )
)
```

### Manual Compaction

```swift
let compacted = try await client.responses.compact(
    model: "gpt-4.1",
    input: .text("Summarize our conversation so far."),
    previousResponseId: previousId
)

// Use compacted context for the next request
let response = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("Now, based on that summary, what should we do next?"),
    previousResponseId: compacted.id
)
```

---

## WebSocket Mode

Persistent WebSocket connections for the Responses API (Darwin only).

### Basic Usage

```swift
import SwiftOpenAI

let client = OpenAI(apiKey: "sk-...")

let ws = client.responses.connectWebSocket()
await ws.connect()

let stream = try await ws.create(
    model: "gpt-4.1",
    input: .text("Hello from WebSocket!")
)

for try await event in stream {
    if event.type == "response.output_text.delta" {
        print(event.delta ?? "", terminator: "")
    }
}
```

### Multi-turn

```swift
let ws = client.responses.connectWebSocket()
await ws.connect()

// First turn
let stream1 = try await ws.create(
    model: "gpt-4.1",
    input: .text("My name is Bob."),
    store: true
)
var firstResponseId = ""
for try await event in stream1 {
    if event.type == "response.completed", let id = event.response?.id {
        firstResponseId = id
    }
}

// Second turn — reference the first
let stream2 = try await ws.create(
    model: "gpt-4.1",
    input: .text("What's my name?"),
    previousResponseId: firstResponseId
)
for try await event in stream2 {
    if event.type == "response.output_text.delta" {
        print(event.delta ?? "", terminator: "")
    }
}

await ws.close()
```

### Function Calling over WebSocket

```swift
let tools: [ResponseTool] = [
    .function(FunctionToolDefinition(
        name: "lookup",
        description: "Look up a value",
        parameters: ["type": "object", "properties": ["key": ["type": "string"]], "required": ["key"]]
    ))
]

let stream = try await ws.create(
    model: "gpt-4.1",
    input: .text("Look up the value for 'status'"),
    tools: tools
)

for try await event in stream {
    if event.type == "response.function_call_arguments.done" {
        print("Function call: \(event.name ?? "")(\(event.arguments ?? ""))")
    }
}
```

### Connection Warmup

Pre-authenticate and reduce latency for the first request:

```swift
let ws = client.responses.connectWebSocket()
await ws.connect()

let responseId = try await ws.warmup(
    model: "gpt-4.1",
    input: .text("Warm up context"),
    instructions: "Be concise."
)
// Connection is now warm — subsequent create() calls are faster
```

> **Tip:** WebSocket mode is ideal for interactive applications where latency matters. The connection persists across multiple requests, avoiding repeated HTTP handshakes.

---

## Conversations API

Create and manage multi-turn conversations as first-class objects.

### Create a Conversation

```swift
import SwiftOpenAI

let client = OpenAI(apiKey: "sk-...")

let conversation = try await client.conversations.create()
print(conversation.id)
```

### Use with Responses

```swift
let conversation = try await client.conversations.create()

let response = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("I'm learning Swift."),
    conversation: conversation.id,
    store: true
)

let followUp = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("What should I learn first?"),
    conversation: conversation.id,
    previousResponseId: response.id
)

print(followUp.outputText ?? "")
```

### Manage Items

```swift
// Add items to a conversation
let items = try await client.conversations.items.create(
    conversationId: conversation.id,
    items: [
        ConversationInputItem(role: "user", content: "What is SwiftUI?")
    ]
)

// List items
let list = try await client.conversations.items.list(conversationId: conversation.id)
for item in list.data {
    print("\(item.role ?? ""): \(item.content ?? "")")
}

// Retrieve a single item
let item = try await client.conversations.items.retrieve(
    list.data.first!.id,
    conversationId: conversation.id
)

// Delete an item
_ = try await client.conversations.items.delete(
    item.id,
    conversationId: conversation.id
)
```

### Conversation Lifecycle

```swift
// Retrieve
let conv = try await client.conversations.retrieve(conversation.id)

// Update metadata
let updated = try await client.conversations.update(
    conversation.id,
    metadata: ["topic": "swift-learning"]
)

// Delete
let deleted = try await client.conversations.delete(conversation.id)
```

### Function Calling in Conversations

```swift
let tools: [ResponseTool] = [
    .function(FunctionToolDefinition(
        name: "search_docs",
        description: "Search documentation",
        parameters: ["type": "object", "properties": ["query": ["type": "string"]], "required": ["query"]]
    ))
]

let conversation = try await client.conversations.create()

let response = try await client.responses.create(
    model: "gpt-4.1",
    input: .text("Find docs about concurrency"),
    conversation: conversation.id,
    tools: tools
)

// Handle function calls, then continue the conversation
for item in response.output where item.type == "function_call" {
    let result = try await client.responses.create(
        model: "gpt-4.1",
        input: .items([
            .itemReference(ItemReference(id: item.id ?? "")),
            .functionCallOutput(FunctionCallOutput(
                callId: item.callId ?? "",
                output: "{\"results\": [\"Swift Concurrency Guide\"]}"
            ))
        ]),
        conversation: conversation.id,
        previousResponseId: response.id,
        tools: tools
    )
    print(result.outputText ?? "")
}
```

---

## Realtime API

> **Note:** The Realtime API is available on Darwin platforms only (iOS, macOS, tvOS, watchOS, visionOS).

Full-duplex WebSocket sessions for text and audio interactions.

### Text Example

```swift
import SwiftOpenAI

let client = OpenAI(apiKey: "sk-...")

let connection = client.realtime.connect(model: "gpt-4o-realtime-preview")
let events = try await connection.start()

// Configure the session
try await connection.sessionUpdate(RealtimeSessionConfig(
    modalities: ["text"],
    instructions: "Be concise and helpful."
))

// Send text and request a response
try await connection.sendText("Hello! What is Swift?")
try await connection.createResponse()

// Listen for events
for try await event in events {
    if event.type == "response.text.delta", let delta = event.delta {
        print(delta, terminator: "")
    }
    if event.type == "response.text.done" {
        break
    }
}
print()

connection.close()
```

### Audio Example

```swift
let connection = client.realtime.connect(model: "gpt-4o-realtime-preview")
let events = try await connection.start()

try await connection.sessionUpdate(RealtimeSessionConfig(
    modalities: ["text", "audio"],
    instructions: "Respond naturally."
))

// Send audio data (base64-encoded PCM16)
try await connection.appendAudio(base64AudioChunk)
try await connection.commitAudio()
try await connection.createResponse()

// Receive audio/text events
for try await event in events {
    switch event.type {
    case "response.audio.delta":
        // Handle audio delta (base64 encoded)
        break
    case "response.text.delta":
        print(event.delta ?? "", terminator: "")
    case "response.done":
        break
    default:
        break
    }
}

connection.close()
```

### RealtimeConnection Methods

| Method | Description |
|--------|-------------|
| `start()` | Connect and return event stream |
| `sessionUpdate(_:)` | Configure session (modalities, instructions, etc.) |
| `sendText(_:role:)` | Send a text message (default role: `"user"`) |
| `appendAudio(_:)` | Append base64-encoded audio data |
| `commitAudio()` | Signal end of audio input |
| `clearAudioBuffer()` | Clear pending audio |
| `createItem(_:after:)` | Add a conversation item |
| `deleteItem(_:)` | Remove a conversation item |
| `createResponse(_:)` | Request a model response |
| `cancelResponse()` | Cancel in-progress response |
| `close()` | Close the WebSocket connection |

---

## Chat Completions API

### Basic Usage

```swift
import SwiftOpenAI

let client = OpenAI(apiKey: "sk-...")

let completion = try await client.chat.completions.create(
    model: "gpt-4.1",
    messages: [
        .user(content: "What is the capital of France?")
    ]
)

print(completion.choices.first?.message.content ?? "")
// → The capital of France is Paris.
```

### Multi-turn

```swift
let completion = try await client.chat.completions.create(
    model: "gpt-4.1",
    messages: [
        .system(content: "You are a helpful math tutor."),
        .user(content: "What is 2 + 2?"),
        .assistant(content: "2 + 2 = 4"),
        .user(content: "What about 2 + 3?")
    ]
)

print(completion.choices.first?.message.content ?? "")
```

### Streaming

```swift
let stream = try await client.chat.completions.createStream(
    model: "gpt-4.1",
    messages: [
        .user(content: "Write a short poem about coding.")
    ]
)

for try await chunk in stream {
    if let delta = chunk.choices.first?.delta.content {
        print(delta, terminator: "")
    }
}
```

### Function Calling

```swift
let tools: [ChatCompletionTool] = [
    ChatCompletionTool(function: FunctionDefinition(
        name: "get_stock_price",
        description: "Get current stock price",
        parameters: ["type": "object", "properties": ["symbol": ["type": "string"]], "required": ["symbol"]]
    ))
]

let completion = try await client.chat.completions.create(
    model: "gpt-4.1",
    messages: [.user(content: "What's Apple's stock price?")],
    tools: tools
)

if let toolCall = completion.choices.first?.message.toolCalls?.first {
    print("Function: \(toolCall.function.name)")
    print("Arguments: \(toolCall.function.arguments)")
}
```

### JSON Mode

```swift
let completion = try await client.chat.completions.create(
    model: "gpt-4.1",
    messages: [
        .system(content: "Respond in JSON."),
        .user(content: "List 3 colors with hex codes.")
    ],
    responseFormat: .jsonObject
)

print(completion.choices.first?.message.content ?? "")
// → {"colors":[{"name":"red","hex":"#FF0000"},{"name":"green","hex":"#00FF00"},{"name":"blue","hex":"#0000FF"}]}
```

### Structured Outputs (Chat)

```swift
let completion = try await client.chat.completions.create(
    model: "gpt-4.1",
    messages: [.user(content: "Generate a user profile.")],
    responseFormat: .jsonSchema(ChatCompletionResponseFormatJSONSchema(
        name: "user_profile",
        schema: [
            "type": "object",
            "properties": [
                "name": ["type": "string"],
                "email": ["type": "string"]
            ],
            "required": ["name", "email"],
            "additionalProperties": false
        ],
        strict: true
    ))
)
```

---

## Other APIs

### Embeddings

```swift
let result = try await client.embeddings.create(
    model: "text-embedding-3-small",
    input: .string("Swift is a powerful language.")
)

print("Dimensions: \(result.data.first?.embedding.count ?? 0)")
```

### Models

```swift
// List all models
let models = try await client.models.list()
for model in models.data {
    print(model.id)
}

// Retrieve a specific model
let model = try await client.models.retrieve("gpt-4.1")

// Delete a fine-tuned model
let deleted = try await client.models.delete("ft:gpt-4.1:my-org:custom:id")
```

### Files

```swift
// Upload
let file = try await client.files.create(
    file: trainingData,
    filename: "training.jsonl",
    purpose: "fine-tune"
)

// List
let files = try await client.files.list()

// Retrieve
let info = try await client.files.retrieve(file.id)

// Download content
let data = try await client.files.content(file.id)

// Delete
let deleted = try await client.files.delete(file.id)
```

### Images

```swift
// Generate
let images = try await client.images.generate(
    prompt: "A sunset over mountains, digital art",
    model: "dall-e-3",
    size: "1024x1024",
    quality: "hd"
)
print(images.data.first?.url ?? "")

// Edit (requires PNG, < 4 MB)
let edited = try await client.images.edit(
    image: pngData,
    prompt: "Add a rainbow to the sky"
)

// Variation
let variation = try await client.images.createVariation(image: pngData)
```

### Audio

```swift
// Transcription
let transcription = try await client.audio.transcriptions.create(
    file: audioData,
    filename: "recording.mp3",
    model: "whisper-1"
)
print(transcription.text)

// Translation (to English)
let translation = try await client.audio.translations.create(
    file: audioData,
    filename: "french_audio.mp3",
    model: "whisper-1"
)
print(translation.text)

// Text-to-Speech
let speechData = try await client.audio.speech.create(
    model: "tts-1-hd",
    input: "Hello, world!",
    voice: "nova"
)
// speechData is raw audio bytes (MP3 by default)
```

### Moderations

```swift
let result = try await client.moderations.create(
    input: .string("Some text to check.")
)

let flagged = result.results.first?.flagged ?? false
print("Flagged: \(flagged)")
```

### Fine-tuning

```swift
// Create a job
let job = try await client.fineTuning.jobs.create(
    model: "gpt-4.1",
    trainingFile: "file-abc123"
)

// List jobs
let jobs = try await client.fineTuning.jobs.list()

// Retrieve
let status = try await client.fineTuning.jobs.retrieve(job.id)

// List events
let events = try await client.fineTuning.jobs.listEvents(job.id)

// List checkpoints
let checkpoints = try await client.fineTuning.jobs.listCheckpoints(job.id)

// Cancel
let cancelled = try await client.fineTuning.jobs.cancel(job.id)
```

### Batches

```swift
// Create
let batch = try await client.batches.create(
    inputFileId: "file-abc123",
    endpoint: "/v1/chat/completions",
    completionWindow: "24h"
)

// List
let batches = try await client.batches.list()

// Retrieve
let status = try await client.batches.retrieve(batch.id)

// Cancel
let cancelled = try await client.batches.cancel(batch.id)
```

### Vector Stores

```swift
// Create
let store = try await client.vectorStores.create(
    name: "My Knowledge Base",
    fileIds: ["file-abc123"]
)

// List / Retrieve / Update / Delete
let stores = try await client.vectorStores.list()
let retrieved = try await client.vectorStores.retrieve(store.id)
let updated = try await client.vectorStores.update(store.id, name: "Updated Name")
let deleted = try await client.vectorStores.delete(store.id)

// Manage files in a store
let vsFile = try await client.vectorStores.files.create(
    vectorStoreId: store.id,
    fileId: "file-xyz789"
)
let vsFiles = try await client.vectorStores.files.list(vectorStoreId: store.id)
let deletedFile = try await client.vectorStores.files.delete(
    vectorStoreId: store.id,
    fileId: vsFile.id
)
```

### Uploads

```swift
// Create an upload session
let upload = try await client.uploads.create(
    filename: "large-file.jsonl",
    purpose: "fine-tune",
    bytes: fileData.count,
    mimeType: "application/jsonl"
)

// Upload parts
let part1 = try await client.uploads.parts.create(
    uploadId: upload.id,
    data: chunk1
)
let part2 = try await client.uploads.parts.create(
    uploadId: upload.id,
    data: chunk2
)

// Complete the upload
let completed = try await client.uploads.complete(
    upload.id,
    partIds: [part1.id, part2.id]
)

// Or cancel
let cancelled = try await client.uploads.cancel(upload.id)
```

### Legacy Completions

> **Note:** The Completions API is legacy. Use the Chat Completions or Responses API for new projects.

```swift
let completion = try await client.completions.create(
    model: "gpt-3.5-turbo-instruct",
    prompt: .string("Once upon a time"),
    maxTokens: 100
)
print(completion.choices.first?.text ?? "")

// Streaming
let stream = try await client.completions.createStream(
    model: "gpt-3.5-turbo-instruct",
    prompt: .string("Once upon a time"),
    maxTokens: 100
)
for try await chunk in stream {
    print(chunk.choices.first?.text ?? "", terminator: "")
}
```

---

## API Reference

<details>
<summary>Complete API reference table</summary>

| Resource | Method | Description |
|----------|--------|-------------|
| **Responses** | | |
| `client.responses` | `create(...)` | Generate a response |
| | `createStream(...)` | Stream a response (SSE) |
| | `retrieve(_:)` | Retrieve a stored response |
| | `delete(_:)` | Delete a stored response |
| | `compact(...)` | Compact conversation context |
| | `connectWebSocket()` | Open WebSocket connection *(Darwin only)* |
| **Chat Completions** | | |
| `client.chat.completions` | `create(...)` | Create a chat completion |
| | `createStream(...)` | Stream a chat completion (SSE) |
| **Conversations** | | |
| `client.conversations` | `create(...)` | Create a conversation |
| | `retrieve(_:)` | Retrieve a conversation |
| | `update(_:metadata:)` | Update a conversation |
| | `delete(_:)` | Delete a conversation |
| `client.conversations.items` | `create(...)` | Add items to a conversation |
| | `list(...)` | List conversation items |
| | `retrieve(_:conversationId:)` | Get a single item |
| | `delete(_:conversationId:)` | Delete an item |
| **Embeddings** | | |
| `client.embeddings` | `create(...)` | Create embeddings |
| **Models** | | |
| `client.models` | `list()` | List available models |
| | `retrieve(_:)` | Retrieve model info |
| | `delete(_:)` | Delete a fine-tuned model |
| **Files** | | |
| `client.files` | `create(...)` | Upload a file |
| | `retrieve(_:)` | Get file metadata |
| | `list(...)` | List files |
| | `delete(_:)` | Delete a file |
| | `content(_:)` | Download file content |
| **Images** | | |
| `client.images` | `generate(...)` | Generate images from text |
| | `edit(...)` | Edit an image |
| | `createVariation(...)` | Create image variations |
| **Audio** | | |
| `client.audio.transcriptions` | `create(...)` | Transcribe audio to text |
| `client.audio.translations` | `create(...)` | Translate audio to English |
| `client.audio.speech` | `create(...)` | Generate speech from text |
| **Moderations** | | |
| `client.moderations` | `create(...)` | Classify text for policy compliance |
| **Fine-tuning** | | |
| `client.fineTuning.jobs` | `create(...)` | Create a fine-tuning job |
| | `retrieve(_:)` | Get job status |
| | `list(...)` | List jobs |
| | `cancel(_:)` | Cancel a job |
| | `listEvents(_:...)` | List job events |
| | `listCheckpoints(_:...)` | List job checkpoints |
| **Batches** | | |
| `client.batches` | `create(...)` | Create a batch |
| | `retrieve(_:)` | Get batch status |
| | `list(...)` | List batches |
| | `cancel(_:)` | Cancel a batch |
| **Vector Stores** | | |
| `client.vectorStores` | `create(...)` | Create a vector store |
| | `retrieve(_:)` | Get a vector store |
| | `update(_:...)` | Update a vector store |
| | `list(...)` | List vector stores |
| | `delete(_:)` | Delete a vector store |
| `client.vectorStores.files` | `create(...)` | Add file to store |
| | `retrieve(...)` | Get file info |
| | `list(...)` | List files in store |
| | `delete(...)` | Remove file from store |
| **Uploads** | | |
| `client.uploads` | `create(...)` | Start an upload session |
| | `cancel(_:)` | Cancel an upload |
| | `complete(_:partIds:...)` | Complete an upload |
| `client.uploads.parts` | `create(...)` | Upload a part |
| **Completions** *(legacy)* | | |
| `client.completions` | `create(...)` | Create a completion |
| | `createStream(...)` | Stream a completion |
| **Realtime** *(Darwin only)* | | |
| `client.realtime` | `connect(model:)` | Open a realtime WebSocket connection |

</details>

---

## Error Handling

All errors are thrown as `OpenAIError`:

```swift
import SwiftOpenAI

do {
    let response = try await client.responses.create(
        model: "gpt-4.1",
        input: .text("Hello!")
    )
} catch let error as OpenAIError {
    switch error {
    case .authenticationError(let message):
        print("Authentication failed (401): \(message)")
    case .permissionDeniedError(let message):
        print("Permission denied (403): \(message)")
    case .notFoundError(let message):
        print("Not found (404): \(message)")
    case .conflictError(let message):
        print("Conflict (409): \(message)")
    case .unprocessableEntityError(let message):
        print("Unprocessable (422): \(message)")
    case .rateLimitError(let message):
        print("Rate limited (429): \(message)")
    case .internalServerError(let message):
        print("Server error (500+): \(message)")
    case .apiError(let statusCode, let message, let type, let code):
        print("API error \(statusCode): \(message) [type: \(type ?? ""), code: \(code ?? "")]")
    case .connectionError(let message):
        print("Connection error: \(message)")
    case .decodingError(let message):
        print("Decoding error: \(message)")
    case .timeout:
        print("Request timed out")
    case .bufferOverflow(let message):
        print("Buffer overflow: \(message)")
    }
}
```

---

## Retry & Resilience

The SDK automatically retries failed requests with exponential backoff and jitter.

### How It Works

- **Retried status codes**: `429` (rate limit) and `5xx` (server errors)
- **Backoff formula**: `min(baseDelay × 2^attempt + jitter, 8s)` — matches the Python SDK
- **Jitter**: Random value in `0…0.25s` to prevent thundering herd
- **Retry-After header**: Respected when present (capped at 120 seconds)
- **Network errors**: Not retried — `URLError` is immediately mapped to `OpenAIError.connectionError`

### Configuration

```swift
let client = OpenAI(
    apiKey: "sk-...",
    maxRetries: 3,     // Retry up to 3 times (set 0 to disable)
    retryDelay: 1.0    // Start with 1s base delay
)
// Retry delays: 1s → 2s → 4s (capped at 8s)
```

---

## Security

SwiftOpenAI is designed with security as a priority:

| Protection | Details |
|-----------|---------|
| **Zero dependencies** | No third-party code in the dependency chain |
| **TLS 1.2+ enforcement** | `tlsMinimumSupportedProtocolVersion = .TLSv12` on Darwin |
| **No API key logging** | API keys are never included in error messages or logs |
| **Header injection prevention** | Organization and project headers are sanitized (CR/LF stripped) |
| **Path traversal prevention** | All path components validated — rejects empty, `/`, `\`, `..` |
| **Cookies disabled** | `httpCookieAcceptPolicy = .never` |
| **Cache disabled** | `urlCache = nil` — no sensitive data stored to disk |
| **Buffer size limits** | 10 MB safety limit on SSE streams, WebSocket frames, and error response bodies |

---

## Performance

| Optimization | Details |
|-------------|---------|
| **Cached URL construction** | Endpoint URLs built once and reused |
| **Pre-built headers** | Common headers cached on the HTTP client |
| **Line-based SSE parsing** | Uses `AsyncLineSequence` on Darwin — avoids per-byte async overhead (100–300x faster) |
| **Explicit CodingKeys** | Faster JSON encoding/decoding than synthesized keys |
| **ContiguousArray multipart** | `ContiguousArray<UInt8>` for efficient multipart body assembly |
| **Connection pre-warming** | `warmConnection()` pre-establishes TCP/TLS for faster first request |
| **HTTP pipelining** | `httpShouldUsePipelining = true` with up to 8 connections per host |

---

## Platform Support

| Platform | Minimum Version | Notes |
|----------|----------------|-------|
| iOS | 16.0+ | Full support |
| macOS | 13.0+ | Full support |
| tvOS | 16.0+ | Full support |
| watchOS | 9.0+ | Full support |
| visionOS | 1.0+ | Full support |
| Linux | Swift 6.0+ | Via `FoundationNetworking` |

> **Note:** WebSocket mode (`connectWebSocket()`) and the Realtime API (`client.realtime`) are **Darwin only** — they require `URLSessionWebSocketTask` which is unavailable on Linux.

> **Note:** On Linux, streaming uses a buffered `Data` fallback since `URLSession.AsyncBytes` is unavailable in swift-corelibs-foundation. Import `FoundationNetworking` alongside `Foundation` in your Linux targets.

---

## Examples

The [`Examples/`](Examples/) directory contains copy-paste-ready usage examples:

| File | Topics |
|------|--------|
| [`BasicUsage.swift`](Examples/BasicUsage.swift) | Models, Embeddings, Moderations, Images, error handling |
| [`ChatExamples.swift`](Examples/ChatExamples.swift) | Chat completions, multi-turn, streaming, tool calling, JSON mode, structured output |
| [`ResponsesExamples.swift`](Examples/ResponsesExamples.swift) | Responses API, `previousResponseId` chaining, streaming, Conversations API |
| [`AdvancedExamples.swift`](Examples/AdvancedExamples.swift) | Audio, fine-tuning, batches, vector stores, chunked uploads, custom configuration |

---

## Testing

SwiftOpenAI includes **141 tests** using the [Swift Testing](https://developer.apple.com/documentation/testing/) framework.

```bash
swift test
```

- All tests mock HTTP responses via `MockURLProtocol` — no real API calls
- Tests are organized in `Tests/SwiftOpenAITests/` mirroring the `Sources/` structure
- Uses `@Suite struct` for test suites (value semantics prevent shared state bugs)
- All tests use `async throws` to match the SDK's async design

---

## CI/CD

### CI Workflow

Runs on every push and pull request to `main`:

- **macOS** — macOS 15, Swift 6.0: `swift build` + `swift test`
- **Linux** — Ubuntu (latest), Swift 6.0 container: `swift build` + `swift test`
- SPM build cache enabled for faster runs

### Release Workflow

Triggered by `v*` tag pushes (e.g., `v0.6.1`):

- Validates build on macOS and Linux in parallel
- Creates a GitHub Release with auto-generated release notes
- Pre-release detected automatically for tags containing `-` (e.g., `v1.0.0-beta`)

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, coding standards, and contribution guidelines.

---

## License

SwiftOpenAI is released under the [MIT License](LICENSE).
