// ChatExamples.swift
// Standalone reference file — NOT compiled by the SwiftOpenAI package.
//
// Each function demonstrates a different Chat Completions feature using the
// SwiftOpenAI SDK. Run any example by calling it from your own async context:
//
//   let client = OpenAI(apiKey: "sk-...")
//   try await simpleChat(client: client)

import Foundation
import SwiftOpenAI

// MARK: - 1. Simple Chat

/// Sends a single user message and prints the assistant's reply.
///
/// This is the simplest possible usage of the Chat Completions API.
func simpleChat(client: OpenAI) async throws {
    let response = try await client.chat.completions.create(
        model: "gpt-4o",
        messages: [
            .user("What is the capital of France?")
        ]
    )

    if let content = response.choices.first?.message.content {
        print("Assistant: \(content)")
    }
}

// MARK: - 2. Multi-turn Conversation

/// Builds a message array simulating a back-and-forth dialogue, showing how
/// to accumulate conversation history across multiple turns.
///
/// The key idea is that you keep appending to the `messages` array: each time
/// the model responds, you add its reply as an `.assistant()` message, then
/// append the next `.user()` message before calling `create()` again.
func multiTurnConversation(client: OpenAI) async throws {
    var messages: [ChatCompletionMessage] = [
        .system("You are a helpful geography tutor."),
        .user("What continent is Brazil in?")
    ]

    // First turn
    let first = try await client.chat.completions.create(
        model: "gpt-4o",
        messages: messages
    )
    let firstReply = first.choices.first?.message.content ?? ""
    print("Turn 1 — Assistant: \(firstReply)")

    // Append assistant reply, then the next user message
    messages.append(.assistant(firstReply))
    messages.append(.user("What is its largest city?"))

    // Second turn
    let second = try await client.chat.completions.create(
        model: "gpt-4o",
        messages: messages
    )
    let secondReply = second.choices.first?.message.content ?? ""
    print("Turn 2 — Assistant: \(secondReply)")

    // Continue accumulating as needed...
    messages.append(.assistant(secondReply))
    messages.append(.user("And what language do they speak there?"))

    let third = try await client.chat.completions.create(
        model: "gpt-4o",
        messages: messages
    )
    let thirdReply = third.choices.first?.message.content ?? ""
    print("Turn 3 — Assistant: \(thirdReply)")
}

// MARK: - 3. System Prompt

/// Uses `.system()` to give the model a specific persona and behavioral rules.
///
/// The system message is always the first element of the messages array and
/// instructs the model on how to behave for the entire conversation.
func systemPrompt(client: OpenAI) async throws {
    let response = try await client.chat.completions.create(
        model: "gpt-4o",
        messages: [
            .system("""
                You are a pirate captain. Respond to every question in pirate \
                speak. Keep answers under two sentences.
                """),
            .user("How do computers work?")
        ]
    )

    if let content = response.choices.first?.message.content {
        print("Pirate says: \(content)")
    }
}

// MARK: - 4. Streaming Chat

/// Uses `createStream()` to receive the response incrementally, printing each
/// token as it arrives.
///
/// The stream yields `ChatCompletionChunk` values. Each chunk's
/// `delta.content` contains a small text fragment. Concatenate them to build
/// the full response.
func streamingChat(client: OpenAI) async throws {
    let stream = try await client.chat.completions.createStream(
        model: "gpt-4o",
        messages: [
            .user("Write a haiku about Swift programming.")
        ]
    )

    var fullResponse = ""
    for try await chunk in stream {
        if let content = chunk.choices.first?.delta.content {
            print(content, terminator: "")   // Print each fragment in real-time
            fullResponse += content
        }
    }
    print() // Final newline
    print("Full response: \(fullResponse)")
}

// MARK: - 5. Function / Tool Calling

/// Demonstrates the full tool-calling round-trip:
/// 1. Define a function tool (get_weather).
/// 2. Send a user message that triggers the tool call.
/// 3. Parse the tool_calls from the response.
/// 4. Build a `.tool()` message with the function result.
/// 5. Send it back to get the final natural-language answer.
func toolCalling(client: OpenAI) async throws {
    // Step 1 — Define the weather tool
    let weatherTool = ChatCompletionTool(
        function: ChatCompletionToolFunction(
            name: "get_weather",
            description: "Get the current weather for a given location.",
            parameters: [
                "type": AnyCodable("object"),
                "properties": AnyCodable([
                    "location": [
                        "type": "string",
                        "description": "City and state, e.g. San Francisco, CA"
                    ],
                    "unit": [
                        "type": "string",
                        "enum": ["celsius", "fahrenheit"]
                    ]
                ]),
                "required": AnyCodable(["location"])
            ]
        )
    )

    // Step 2 — Send a message that should trigger the tool
    let firstResponse = try await client.chat.completions.create(
        model: "gpt-4o",
        messages: [
            .user("What's the weather like in San Francisco today?")
        ],
        tools: [weatherTool],
        toolChoice: .auto
    )

    guard let choice = firstResponse.choices.first else { return }

    // Step 3 — Check if the model wants to call a tool
    if let toolCalls = choice.message.toolCalls, !toolCalls.isEmpty {
        for toolCall in toolCalls {
            print("Tool call: \(toolCall.function.name)(\(toolCall.function.arguments))")

            // Step 4 — Execute the function (simulated here) and build a .tool() reply
            let weatherResult = """
                {"temperature": 62, "unit": "fahrenheit", "description": "Foggy with partial clouds"}
                """

            // Step 5 — Send the tool result back to the model
            let finalResponse = try await client.chat.completions.create(
                model: "gpt-4o",
                messages: [
                    .user("What's the weather like in San Francisco today?"),
                    .assistant("", toolCalls: toolCalls),
                    .tool(weatherResult, toolCallId: toolCall.id)
                ],
                tools: [weatherTool]
            )

            if let content = finalResponse.choices.first?.message.content {
                print("Final answer: \(content)")
            }
        }
    } else {
        // Model answered directly without calling a tool
        print("Direct answer: \(choice.message.content ?? "")")
    }
}

// MARK: - 6. JSON Mode

/// Uses `responseFormat: .jsonObject` to guarantee the model outputs valid JSON.
///
/// When using JSON mode you **must** instruct the model to produce JSON in the
/// system or user message — the API requires this.
func jsonMode(client: OpenAI) async throws {
    let response = try await client.chat.completions.create(
        model: "gpt-4o",
        messages: [
            .system("You are a helpful assistant that responds in JSON."),
            .user("""
                List the three largest planets in our solar system. \
                Return a JSON object with a "planets" array where each element \
                has "name", "diameter_km", and "type" fields.
                """)
        ],
        responseFormat: .jsonObject
    )

    if let json = response.choices.first?.message.content {
        print("JSON response:\n\(json)")

        // Parse the JSON into a Swift dictionary
        if let data = json.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print("Parsed keys: \(parsed.keys.sorted())")
        }
    }
}

// MARK: - 7. Configuring Parameters

/// Shows how to fine-tune generation with temperature, maxCompletionTokens,
/// stop sequences, and a deterministic seed.
///
/// - `temperature`: Controls randomness (0 = deterministic, 2 = very random).
/// - `maxCompletionTokens`: Caps the response length.
/// - `stop`: Stops generation when the model emits one of these sequences.
/// - `seed`: Enables (mostly) deterministic output for the same input.
func configuringParameters(client: OpenAI) async throws {
    let response = try await client.chat.completions.create(
        model: "gpt-4o",
        messages: [
            .system("You are a concise technical writer."),
            .user("Explain what an async/await pattern is.")
        ],
        temperature: 0.2,
        maxCompletionTokens: 150,
        stop: .strings(["---", "END"]),
        seed: 42
    )

    if let content = response.choices.first?.message.content {
        print("Response (temp=0.2, max=150, seed=42):\n\(content)")
    }

    // The system fingerprint helps verify deterministic behavior
    if let fingerprint = response.systemFingerprint {
        print("System fingerprint: \(fingerprint)")
    }
    if let usage = response.usage {
        print("Tokens — prompt: \(usage.promptTokens), completion: \(usage.completionTokens ?? 0), total: \(usage.totalTokens)")
    }
}
