// Examples/BasicUsage.swift
// Basic usage examples for SwiftOpenAI
//
// These examples demonstrate common API operations.
// Set your API key in the OPENAI_API_KEY environment variable.

import Foundation
import SwiftOpenAI

// MARK: - Setup

/// Create a client from environment variable.
func makeClient() -> OpenAI {
    let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    return OpenAI(apiKey: apiKey)
}

// MARK: - Models

/// List all available models.
func listModels() async throws {
    let client = makeClient()
    let response = try await client.models.list()
    for model in response.data {
        print("\(model.id) — owned by \(model.ownedBy)")
    }
}

/// Get details about a specific model.
func getModel() async throws {
    let client = makeClient()
    let model = try await client.models.retrieve("gpt-4o")
    print("Model: \(model.id), created: \(model.created)")
}

// MARK: - Embeddings

/// Generate embeddings for text.
func createEmbedding() async throws {
    let client = makeClient()
    let response = try await client.embeddings.create(
        model: "text-embedding-3-small",
        input: .string("Swift is a powerful programming language")
    )
    let vector = response.data.first!.embedding
    print("Embedding dimensions: \(vector.count)")
    print("First 5 values: \(Array(vector.prefix(5)))")
}

/// Generate embeddings with reduced dimensions.
func createCompactEmbedding() async throws {
    let client = makeClient()
    let response = try await client.embeddings.create(
        model: "text-embedding-3-small",
        input: .strings(["Hello", "World"]),
        dimensions: 256
    )
    print("Got \(response.data.count) embeddings, each \(response.data.first!.embedding.count) dims")
    print("Tokens used: \(response.usage.totalTokens)")
}

// MARK: - Moderations

/// Check text for policy violations.
func moderateText() async throws {
    let client = makeClient()
    let result = try await client.moderations.create(
        input: .string("This is a perfectly safe message about cooking pasta")
    )
    let moderation = result.results.first!
    print("Flagged: \(moderation.flagged)")
    print("Violence score: \(moderation.categoryScores.violence)")
}

// MARK: - Images

/// Generate an image from a text prompt.
func generateImage() async throws {
    let client = makeClient()
    let response = try await client.images.generate(
        prompt: "A serene Japanese garden with cherry blossoms, watercolor style",
        model: "dall-e-3",
        size: "1024x1024",
        quality: "hd"
    )
    if let image = response.data.first {
        print("Image URL: \(image.url ?? "N/A")")
        print("Revised prompt: \(image.revisedPrompt ?? "N/A")")
    }
}

// MARK: - Error Handling

/// Demonstrates error handling patterns.
func handleErrors() async {
    let client = OpenAI(apiKey: "invalid-key")
    do {
        _ = try await client.models.list()
    } catch let error as OpenAIError {
        switch error {
        case .authenticationError(let message):
            print("Authentication failed: \(message)")
        case .rateLimitError(let message):
            print("Rate limited — retry after delay: \(message)")
        case .notFoundError(let message):
            print("Resource not found: \(message)")
        case .apiError(let statusCode, let message, let type, _):
            print("API error \(statusCode) [\(type ?? "unknown")]: \(message)")
        case .connectionError(let underlying):
            print("Network error: \(underlying.localizedDescription)")
        case .timeout:
            print("Request timed out")
        default:
            print("Other error: \(error)")
        }
    } catch {
        print("Unexpected error: \(error)")
    }
}
