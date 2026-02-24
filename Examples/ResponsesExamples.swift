// ResponsesExamples.swift
// Standalone reference file — NOT compiled by the SwiftOpenAI package.
// Demonstrates the Responses API using SwiftOpenAI.

import SwiftOpenAI
import Foundation

// MARK: - Helper

/// Creates an OpenAI client for use in the examples.
private func makeClient() -> OpenAI {
    let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    let baseURL = ProcessInfo.processInfo.environment["OPENAI_BASE_URL"].flatMap { URL(string: $0) }
    return OpenAI(apiKey: apiKey, baseURL: baseURL)
}

// MARK: - 1. Simple Text Response

/// Creates a simple response from a text prompt and prints the output.
func simpleTextResponse() async throws {
    let client = makeClient()

    let response = try await client.responses.create(
        model: "gpt-4o",
        input: .text("What is the capital of France?")
    )

    let text = response.output.first?.content?.first?.text ?? ""
    print("Response: \(text)")
    print("Model: \(response.model)")
    print("Status: \(response.status)")

    // Print token usage if available.
    if let usage = response.usage {
        print("Tokens — input: \(usage.inputTokens), output: \(usage.outputTokens), total: \(usage.totalTokens)")
    }
}

// MARK: - 2. Multi-Turn Conversation with previousResponseId

/// Demonstrates multi-turn conversations using `previousResponseId`.
///
/// The Responses API tracks conversation history server-side. Instead of
/// manually accumulating messages, you simply pass the previous response's
/// ID to continue the conversation. The model sees all prior turns automatically.
func multiTurnConversation() async throws {
    let client = makeClient()

    // Turn 1 — start the conversation
    let response1 = try await client.responses.create(
        model: "gpt-4o",
        input: .text("My name is Alice. What's a good programming language to learn?"),
        store: true  // Must store to enable multi-turn via previousResponseId
    )
    let turn1Text = response1.output.first?.content?.first?.text ?? ""
    print("Turn 1 — Assistant: \(turn1Text)")
    print("  Response ID: \(response1.id)")

    // Turn 2 — continue the conversation by passing the previous response ID
    // No need to re-send the full message history!
    let response2 = try await client.responses.create(
        model: "gpt-4o",
        input: .text("Why did you recommend that? Also, do you remember my name?"),
        previousResponseId: response1.id  // ← Links to the previous turn
    )
    let turn2Text = response2.output.first?.content?.first?.text ?? ""
    print("Turn 2 — Assistant: \(turn2Text)")
    print("  Previous Response ID: \(response2.previousResponseId ?? "nil")")

    // Turn 3 — chain another turn
    let response3 = try await client.responses.create(
        model: "gpt-4o",
        input: .text("Can you give me a simple code example in that language?"),
        previousResponseId: response2.id
    )
    let turn3Text = response3.output.first?.content?.first?.text ?? ""
    print("Turn 3 — Assistant: \(turn3Text)")
}

// MARK: - 3. Multi-Turn with Manual History (Alternative)

/// For cases where you don't want server-side storage, you can also pass
/// the full message history manually — similar to the Chat Completions API.
func multiTurnManualHistory() async throws {
    let client = makeClient()

    // Turn 1
    let response1 = try await client.responses.create(
        model: "gpt-4o",
        input: .text("What continent is Brazil in?")
    )
    let turn1Text = response1.output.first?.content?.first?.text ?? ""
    print("Turn 1 — Assistant: \(turn1Text)")

    // Turn 2 — pass the full conversation history as messages
    let response2 = try await client.responses.create(
        model: "gpt-4o",
        input: .messages([
            ResponseInputMessage(role: "user", content: "What continent is Brazil in?"),
            ResponseInputMessage(role: "assistant", content: turn1Text),
            ResponseInputMessage(role: "user", content: "What is its largest city?"),
        ])
    )
    let turn2Text = response2.output.first?.content?.first?.text ?? ""
    print("Turn 2 — Assistant: \(turn2Text)")
}

// MARK: - 4. With Instructions (System Prompt)

/// Uses the `instructions` parameter to set a system-level persona.
func responseWithInstructions() async throws {
    let client = makeClient()

    let response = try await client.responses.create(
        model: "gpt-4o",
        input: .text("Explain recursion."),
        instructions: "You are a patient teacher who explains concepts using simple analogies. Keep answers under 100 words."
    )

    let text = response.output.first?.content?.first?.text ?? ""
    print("Teacher says: \(text)")
}

// MARK: - 5. Streaming Responses

/// Streams a response and prints events as they arrive.
func streamingResponse() async throws {
    let client = makeClient()

    let stream = try await client.responses.createStream(
        model: "gpt-4o",
        input: .text("Write a haiku about Swift programming.")
    )

    for try await event in stream {
        print("Event type: \(event.type)")

        // The final "response.done" event carries the completed response.
        if event.type == "response.done", let response = event.response {
            let text = response.output.first?.content?.first?.text ?? ""
            print("\nCompleted response:\n\(text)")
        }
    }
}

// MARK: - 6. Retrieve and Delete

/// Creates a stored response, retrieves it by ID, then deletes it.
func retrieveAndDelete() async throws {
    let client = makeClient()

    // Create a response with `store: true` so it persists server-side.
    let created = try await client.responses.create(
        model: "gpt-4o",
        input: .text("Hello, world!"),
        store: true
    )
    print("Created response ID: \(created.id)")

    // Retrieve the same response by its ID.
    let retrieved = try await client.responses.retrieve(created.id)
    print("Retrieved response status: \(retrieved.status)")
    print("Retrieved text: \(retrieved.output.first?.content?.first?.text ?? "")")

    // Delete the response when it's no longer needed.
    let deleted = try await client.responses.delete(created.id)
    print("Deleted response ID: \(deleted.id)")
}

// MARK: - 7. With Metadata

/// Attaches arbitrary key-value metadata to a response for tracking.
func responseWithMetadata() async throws {
    let client = makeClient()

    let response = try await client.responses.create(
        model: "gpt-4o",
        input: .text("Summarize the benefits of Swift concurrency."),
        metadata: [
            "user_id": "user_123",
            "session_id": "sess_abc",
            "purpose": "documentation",
        ]
    )

    let text = response.output.first?.content?.first?.text ?? ""
    print("Response: \(text)")

    if let metadata = response.metadata {
        print("Metadata: \(metadata)")
    }
}

// MARK: - 8. Controlling Output

/// Demonstrates temperature, maxOutputTokens, and topP parameters.
func controlledOutput() async throws {
    let client = makeClient()

    // Low temperature (0.0) for deterministic, focused answers.
    let precise = try await client.responses.create(
        model: "gpt-4o",
        input: .text("What is 2 + 2?"),
        maxOutputTokens: 50,
        temperature: 0.0,
        topP: 1.0
    )
    print("Precise: \(precise.output.first?.content?.first?.text ?? "")")

    // Higher temperature (1.2) for more creative output.
    let creative = try await client.responses.create(
        model: "gpt-4o",
        input: .text("Write a one-sentence story about a robot."),
        maxOutputTokens: 200,
        temperature: 1.2,
        topP: 0.9
    )
    print("Creative: \(creative.output.first?.content?.first?.text ?? "")")
}
