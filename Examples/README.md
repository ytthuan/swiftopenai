# SwiftOpenAI Examples

Standalone Swift reference files demonstrating every feature of the SwiftOpenAI SDK.

> **Note:** These files are **not compiled** as part of the SwiftOpenAI package.
> Copy any snippet into your own project that depends on SwiftOpenAI.

## Setup

All examples expect an `OPENAI_API_KEY` environment variable:

```bash
export OPENAI_API_KEY="sk-..."
```

```swift
import SwiftOpenAI

let client = OpenAI(apiKey: ProcessInfo.processInfo.environment["OPENAI_API_KEY"]!)
```

---

## File Overview

| File | Topics Covered |
|------|---------------|
| [BasicUsage.swift](#basicusageswift) | Models, Embeddings, Moderations, Images, Error Handling |
| [ChatExamples.swift](#chatexamplesswift) | Chat Completions, Conversations, Streaming, Tool Calling, JSON Mode |
| [ResponsesExamples.swift](#responsesexamplesswift) | Responses API, `previousResponseId` Conversations, Streaming, Conversations API |
| [AdvancedExamples.swift](#advancedexamplesswift) | Audio, Fine-Tuning, Batches, Vector Stores, Uploads, Custom Config |

---

## BasicUsage.swift

Covers fundamental operations that most apps need.

### List Models
```swift
let response = try await client.models.list()
for model in response.data {
    print("\(model.id) — owned by \(model.ownedBy)")
}
```

### Create Embeddings
```swift
let response = try await client.embeddings.create(
    model: "text-embedding-3-small",
    input: .string("Swift is a powerful programming language")
)
let vector = response.data.first!.embedding
print("Dimensions: \(vector.count)")
```

### Content Moderation
```swift
let result = try await client.moderations.create(
    input: .string("This is a safe message")
)
print("Flagged: \(result.results.first!.flagged)")
```

### Image Generation
```swift
let response = try await client.images.generate(
    prompt: "A serene Japanese garden, watercolor style",
    model: "dall-e-3",
    size: "1024x1024",
    quality: "hd"
)
print("URL: \(response.data.first?.url ?? "")")
```

### Error Handling
```swift
do {
    _ = try await client.models.list()
} catch let error as OpenAIError {
    switch error {
    case .authenticationError(let msg): print("Auth: \(msg)")
    case .rateLimitError(let msg):      print("Rate limit: \(msg)")
    case .notFoundError(let msg):       print("Not found: \(msg)")
    case .connectionError(let msg):     print("Network: \(msg)")
    case .timeout:                      print("Timed out")
    default:                            print("Error: \(error)")
    }
}
```

---

## ChatExamples.swift

Comprehensive Chat Completions API coverage.

### 1. Simple Chat
```swift
let response = try await client.chat.completions.create(
    model: "gpt-4o",
    messages: [.user("What is the capital of France?")]
)
print(response.choices.first?.message.content ?? "")
```

### 2. Multi-Turn Conversation
Accumulate message history across turns:
```swift
var messages: [ChatCompletionMessage] = [
    .system("You are a helpful tutor."),
    .user("What continent is Brazil in?")
]
let first = try await client.chat.completions.create(model: "gpt-4o", messages: messages)

// Append assistant reply, then next user message
messages.append(.assistant(first.choices.first?.message.content ?? ""))
messages.append(.user("What is its largest city?"))

let second = try await client.chat.completions.create(model: "gpt-4o", messages: messages)
```

### 3. System Prompt
```swift
let response = try await client.chat.completions.create(
    model: "gpt-4o",
    messages: [
        .system("You are a pirate captain. Respond in pirate speak."),
        .user("How do computers work?")
    ]
)
```

### 4. Streaming
```swift
let stream = try await client.chat.completions.createStream(
    model: "gpt-4o",
    messages: [.user("Write a haiku about Swift.")]
)
for try await chunk in stream {
    if let content = chunk.choices.first?.delta.content {
        print(content, terminator: "")
    }
}
```

### 5. Tool / Function Calling
Full round-trip: define tool → model calls it → you execute → return result → model answers.
```swift
let weatherTool = ChatCompletionTool(
    function: ChatCompletionToolFunction(
        name: "get_weather",
        description: "Get weather for a location.",
        parameters: [
            "type": AnyCodable("object"),
            "properties": AnyCodable([
                "location": ["type": "string", "description": "City, e.g. San Francisco, CA"]
            ]),
            "required": AnyCodable(["location"])
        ]
    )
)

let response = try await client.chat.completions.create(
    model: "gpt-4o",
    messages: [.user("What's the weather in SF?")],
    tools: [weatherTool],
    toolChoice: .auto
)

// Check for tool_calls, execute, send result back...
```

### 6. JSON Mode
```swift
let response = try await client.chat.completions.create(
    model: "gpt-4o",
    messages: [
        .system("Respond in JSON."),
        .user("List the 3 largest planets as JSON with name and diameter_km.")
    ],
    responseFormat: .jsonObject
)
```

### 7. Structured Output (JSON Schema)
```swift
let response = try await client.chat.completions.create(
    model: "gpt-4o",
    messages: [.user("List the 3 largest planets.")],
    responseFormat: .jsonSchema(
        name: "planets",
        schema: [
            "type": AnyCodable("object"),
            "properties": AnyCodable([
                "planets": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string"],
                            "diameter_km": ["type": "number"]
                        ]
                    ]
                ]
            ])
        ],
        strict: true
    )
)
```

---

## ResponsesExamples.swift

The **Responses API** is OpenAI's newer API that simplifies multi-turn conversations
with server-side state management via `previousResponseId`.

### 1. Simple Text Response
```swift
let response = try await client.responses.create(
    model: "gpt-4o",
    input: .text("What is the capital of France?")
)
let text = response.output.first?.content?.first?.text ?? ""
```

### 2. Multi-Turn Conversation with `previousResponseId`

The key feature of the Responses API — **no manual message history needed**.
Pass the previous response's ID and the server automatically includes all prior context:

```swift
// Turn 1 — start conversation (must store to enable chaining)
let turn1 = try await client.responses.create(
    model: "gpt-4o",
    input: .text("My name is Alice. What language should I learn?"),
    store: true
)
print(turn1.output.first?.content?.first?.text ?? "")

// Turn 2 — just pass previousResponseId, no history to manage!
let turn2 = try await client.responses.create(
    model: "gpt-4o",
    input: .text("Why that one? Do you remember my name?"),
    previousResponseId: turn1.id  // ← Server loads full conversation context
)
print(turn2.output.first?.content?.first?.text ?? "")

// Turn 3 — chain as many turns as needed
let turn3 = try await client.responses.create(
    model: "gpt-4o",
    input: .text("Show me a code example."),
    previousResponseId: turn2.id
)
print(turn3.output.first?.content?.first?.text ?? "")

// The response object also tracks the chain:
print(turn3.previousResponseId)  // → turn2.id
```

### 3. Multi-Turn with Manual History (Alternative)
For cases where you don't want server-side storage:
```swift
let response = try await client.responses.create(
    model: "gpt-4o",
    input: .messages([
        ResponseInputMessage(role: "user", content: "What continent is Brazil in?"),
        ResponseInputMessage(role: "assistant", content: "South America."),
        ResponseInputMessage(role: "user", content: "What is its largest city?"),
    ])
)
```

### 4. With Instructions (System Prompt)
```swift
let response = try await client.responses.create(
    model: "gpt-4o",
    input: .text("Explain recursion."),
    instructions: "You are a patient teacher. Use simple analogies. Keep answers under 100 words."
)
```

### 5. Streaming
```swift
let stream = try await client.responses.createStream(
    model: "gpt-4o",
    input: .text("Write a haiku about Swift programming.")
)
for try await event in stream {
    if event.type == "response.done", let response = event.response {
        let text = response.output.first?.content?.first?.text ?? ""
        print(text)
    }
}
```

### 6. Streaming Conversation with `previousResponseId`
```swift
// Start a conversation, then stream the follow-up:
let turn1 = try await client.responses.create(
    model: "gpt-4o",
    input: .text("Tell me about Swift concurrency."),
    store: true
)

let stream = try await client.responses.createStream(
    model: "gpt-4o",
    input: .text("Now explain async/await specifically."),
    previousResponseId: turn1.id
)
for try await event in stream { /* ... */ }
```

### 7. Store, Retrieve, and Delete
```swift
let created = try await client.responses.create(
    model: "gpt-4o",
    input: .text("Hello!"),
    store: true
)

let retrieved = try await client.responses.retrieve(created.id)
let deleted = try await client.responses.delete(created.id)
```

### 8. With Metadata
```swift
let response = try await client.responses.create(
    model: "gpt-4o",
    input: .text("Summarize Swift concurrency."),
    metadata: ["user_id": "user_123", "session_id": "sess_abc"]
)
```

### Chat Completions vs Responses API — When to Use Which?

| Feature | Chat Completions | Responses API |
|---------|-----------------|---------------|
| Conversation state | Client-managed (pass full message array) | Server-managed via `previousResponseId` |
| Streaming | `createStream()` → `ChatCompletionChunk` | `createStream()` → `ResponseStreamEvent` |
| Tool calling | Full support | Coming soon |
| JSON mode / Structured output | `.jsonObject`, `.jsonSchema(...)` | Not yet available |
| Best for | Fine control, tool calling, structured output | Simple multi-turn conversations, rapid prototyping |

### 9. Conversations API

The **Conversations API** provides explicit server-side conversation containers.
Create a conversation, add items to it, list history, and use it alongside the Responses API.

```swift
// Create a conversation with initial context
let conversation = try await client.conversations.create(
    items: [
        .system("You are a helpful Swift tutor."),
        .user("What is an optional?"),
    ],
    metadata: ["topic": "swift-basics"]
)

// Add more items to the conversation
try await client.conversations.items.create(
    conversationId: conversation.id,
    items: [
        .assistant("An optional is a type that can hold a value or nil..."),
        .user("Show me an example?"),
    ]
)

// List all items in the conversation
let history = try await client.conversations.items.list(
    conversationId: conversation.id,
    order: "asc"
)
for item in history.data {
    print("[\(item.role ?? "?")] \(item.content?.first?.text ?? "")")
}

// Update metadata
try await client.conversations.update(
    conversation.id,
    metadata: ["status": "completed"]
)

// Delete when done
try await client.conversations.delete(conversation.id)
```

### 10. Conversations + Responses API Together
```swift
// Use Responses API with previousResponseId, then persist to a Conversation
let response1 = try await client.responses.create(
    model: "gpt-4o",
    input: .text("What is structured concurrency?"),
    store: true
)

let response2 = try await client.responses.create(
    model: "gpt-4o",
    input: .text("How does TaskGroup work?"),
    previousResponseId: response1.id
)

// Save to a conversation for long-term storage
let conv = try await client.conversations.create()
try await client.conversations.items.create(
    conversationId: conv.id,
    items: [
        .user("What is structured concurrency?"),
        .assistant(response1.output.first?.content?.first?.text ?? ""),
        .user("How does TaskGroup work?"),
        .assistant(response2.output.first?.content?.first?.text ?? ""),
    ]
)
```

---

## AdvancedExamples.swift

Production-oriented workflows for specialized APIs.

### Audio Transcription
```swift
let audioData = try Data(contentsOf: URL(fileURLWithPath: "recording.mp3"))
let result = try await client.audio.transcriptions.create(
    file: audioData,
    filename: "recording.mp3",
    model: "whisper-1",
    language: "en"
)
print(result.text)
```

### Text-to-Speech
```swift
let audioData = try await client.audio.speech.create(
    model: "tts-1-hd",
    input: "Hello, world!",
    voice: "nova"
)
try audioData.write(to: URL(fileURLWithPath: "/tmp/speech.mp3"))
```

### Fine-Tuning Workflow
Upload training data → create job → poll until complete:
```swift
let file = try await client.files.create(file: trainingData, filename: "train.jsonl", purpose: "fine-tune")
let job = try await client.fineTuning.jobs.create(model: "gpt-4o-mini-2024-07-18", trainingFile: file.id)

// Poll for completion
var current = job
while ["validating_files", "queued", "running"].contains(current.status) {
    try await Task.sleep(nanoseconds: 30_000_000_000)
    current = try await client.fineTuning.jobs.retrieve(job.id)
}
print("Model: \(current.fineTunedModel ?? "")")
```

### Batch Processing
```swift
let file = try await client.files.create(file: batchData, filename: "batch.jsonl", purpose: "batch")
let batch = try await client.batches.create(
    inputFileId: file.id,
    endpoint: "/v1/chat/completions",
    completionWindow: "24h"
)
```

### Vector Stores
```swift
let store = try await client.vectorStores.create(
    name: "Knowledge Base",
    fileIds: ["file-abc", "file-def"]
)
```

### Chunked Uploads (Large Files)
```swift
let upload = try await client.uploads.create(
    filename: "large.jsonl", purpose: "fine-tune",
    bytes: fileData.count, mimeType: "application/jsonl"
)

// Upload parts
for chunk in chunks {
    let part = try await client.uploads.parts.create(uploadId: upload.id, data: chunk)
    partIds.append(part.id)
}

// Complete
let completed = try await client.uploads.complete(upload.id, partIds: partIds)
```

### Custom Configuration
```swift
// Azure OpenAI
let client = OpenAI(
    apiKey: "azure-key",
    baseURL: URL(string: "https://your-resource.openai.azure.com/openai/deployments/your-deployment")!,
    timeoutInterval: 120
)

// Organization + Project scoping
let client = OpenAI(
    apiKey: "sk-...",
    organization: "org-YourOrgId",
    project: "proj-YourProjectId"
)
```

---

## Running an Example

Since these are standalone reference files, copy the function you need into your own project:

```swift
import SwiftOpenAI

@main
struct MyApp {
    static func main() async throws {
        let client = OpenAI(
            apiKey: ProcessInfo.processInfo.environment["OPENAI_API_KEY"]!
        )

        // Run any example function
        let response = try await client.responses.create(
            model: "gpt-4o",
            input: .text("Hello from SwiftOpenAI!")
        )
        print(response.output.first?.content?.first?.text ?? "")
    }
}
```

## Requirements

- **SwiftOpenAI** package (see [main README](../README.md) for installation)
- **OPENAI_API_KEY** environment variable with a valid API key
- Swift 6.0+ / Xcode 16+
