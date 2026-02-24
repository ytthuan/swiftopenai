// ResponsesExamples.swift
// Standalone reference file — NOT compiled by the SwiftOpenAI package.
// Demonstrates the Responses API using SwiftOpenAI.

import SwiftOpenAI
import Foundation

// MARK: - Helper

/// Creates an OpenAI client for use in the examples.
private func makeClient() -> OpenAI {
    let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    return OpenAI(apiKey: apiKey)
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

// MARK: - 2. Multi-Turn Conversation

/// Demonstrates a multi-turn conversation by building up message history.
func multiTurnConversation() async throws {
    let client = makeClient()

    // Turn 1
    let response1 = try await client.responses.create(
        model: "gpt-4o",
        input: .text("My name is Alice. What's a good programming language to learn?")
    )
    let turn1Text = response1.output.first?.content?.first?.text ?? ""
    print("Assistant: \(turn1Text)")

    // Turn 2 — include conversation history so the model has context.
    let response2 = try await client.responses.create(
        model: "gpt-4o",
        input: .messages([
            ResponseInputMessage(role: "user", content: "My name is Alice. What's a good programming language to learn?"),
            ResponseInputMessage(role: "assistant", content: turn1Text),
            ResponseInputMessage(role: "user", content: "Why did you recommend that? Also, do you remember my name?"),
        ])
    )
    let turn2Text = response2.output.first?.content?.first?.text ?? ""
    print("Assistant: \(turn2Text)")
}

// MARK: - 3. With Instructions (System Prompt)

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

// MARK: - 4. Streaming Responses

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

// MARK: - 5. Retrieve and Delete

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

// MARK: - 6. With Metadata

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

// MARK: - 7. Controlling Output

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
