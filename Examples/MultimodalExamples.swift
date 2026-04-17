// MultimodalExamples.swift
// Standalone reference file — NOT compiled by the SwiftOpenAI package.
//
// Each function demonstrates a different multimodal (text + image) feature
// using the SwiftOpenAI SDK. Run any example by calling it from your own
// async context:
//
//   try await MultimodalExamples.chatWithImageURL()

import Foundation
import SwiftOpenAI

/// Examples demonstrating multimodal (text + image) input with SwiftOpenAI.
///
/// Covers both Chat Completions (vision) and the Responses API with image inputs.
enum MultimodalExamples {

    // MARK: - Chat Completions with Vision

    /// Sends a text + image URL to GPT-4o using the convenience method.
    ///
    /// The `.user(text:imageURL:detail:)` convenience builds a `.userParts`
    /// message with one text part and one image URL part automatically.
    ///
    /// Usage:
    /// ```swift
    /// try await MultimodalExamples.chatWithImageURL()
    /// ```
    static func chatWithImageURL() async throws {
        let client = OpenAI(apiKey: "your-api-key")

        let imageURL = "https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/PNG_transparency_demonstration_1.png/280px-PNG_transparency_demonstration_1.png"

        let response = try await client.chat.completions.create(
            model: "gpt-4o",
            messages: [
                .user(
                    text: "What do you see in this image? Describe it briefly.",
                    imageURL: imageURL,
                    detail: .high
                )
            ]
        )

        if let content = response.choices.first?.message.content {
            print("Assistant: \(content)")
        }
    }

    /// Sends a text + base64-encoded image to GPT-4o.
    ///
    /// Shows two approaches for embedding raw `Data` as a base64 image:
    /// 1. High-level convenience via `.user(text:imageData:mimeType:detail:)`.
    /// 2. Parts-based with the `.imageData(_:mimeType:detail:)` factory.
    ///
    /// Usage:
    /// ```swift
    /// try await MultimodalExamples.chatWithBase64Image()
    /// ```
    static func chatWithBase64Image() async throws {
        let client = OpenAI(apiKey: "your-api-key")

        // In a real app, load your image data from disk or generate it:
        //   let imageData = try Data(contentsOf: imageFileURL)
        let imageData = Data()  // your image data here

        // Approach 1: High-level convenience (recommended)
        let message: ChatCompletionMessage = .user(
            text: "What does this image show?",
            imageData: imageData,
            mimeType: .png,
            detail: .low
        )

        let response = try await client.chat.completions.create(
            model: "gpt-4o",
            messages: [message]
        )

        if let content = response.choices.first?.message.content {
            print("Assistant: \(content)")
        }

        // Approach 2: Parts-based with .imageData factory
        let message2: ChatCompletionMessage = .user(parts: [
            .text("Describe this image"),
            .imageData(imageData, mimeType: .jpeg, detail: .high),
        ])

        let response2 = try await client.chat.completions.create(
            model: "gpt-4o",
            messages: [message2]
        )

        if let content = response2.choices.first?.message.content {
            print("Assistant: \(content)")
        }
    }

    /// Sends multiple images in a single message using `.userParts`.
    ///
    /// The parts-based approach lets you compose any combination of text
    /// and image parts in a single user message.
    ///
    /// Usage:
    /// ```swift
    /// try await MultimodalExamples.chatWithMultipleImages()
    /// ```
    static func chatWithMultipleImages() async throws {
        let client = OpenAI(apiKey: "your-api-key")

        let imageA = "https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/PNG_transparency_demonstration_1.png/280px-PNG_transparency_demonstration_1.png"
        let imageB = "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a7/Camponotus_flavomarginatus_ant.jpg/320px-Camponotus_flavomarginatus_ant.jpg"

        let response = try await client.chat.completions.create(
            model: "gpt-4o",
            messages: [
                .user(parts: [
                    .text("Compare these two images. What are the differences?"),
                    .imageURL(ChatCompletionImageURL(url: imageA, detail: .auto)),
                    .imageURL(ChatCompletionImageURL(url: imageB, detail: .auto)),
                ])
            ]
        )

        if let content = response.choices.first?.message.content {
            print("Assistant: \(content)")
        }
    }

    /// Demonstrates that plain text `.user("...")` messages still work.
    ///
    /// The multimodal additions are fully backward compatible — existing
    /// code using `.user("text")` continues to work without changes.
    ///
    /// Usage:
    /// ```swift
    /// try await MultimodalExamples.chatPlainTextStillWorks()
    /// ```
    static func chatPlainTextStillWorks() async throws {
        let client = OpenAI(apiKey: "your-api-key")

        // Plain text — exactly the same syntax as before multimodal was added
        let response = try await client.chat.completions.create(
            model: "gpt-4o",
            messages: [
                .system("You are a helpful assistant."),
                .user("What is the capital of Japan?")
            ]
        )

        if let content = response.choices.first?.message.content {
            print("Assistant: \(content)")
        }
    }

    // MARK: - Responses API with Vision

    /// Sends a text + image URL via the Responses API.
    ///
    /// The Responses API uses `ResponseInputMessage` and `ResponseInputContentPart`
    /// for multimodal input. Use `.inputText` for text and `.inputImage` for images.
    ///
    /// Usage:
    /// ```swift
    /// try await MultimodalExamples.responsesWithImageURL()
    /// ```
    static func responsesWithImageURL() async throws {
        let client = OpenAI(apiKey: "your-api-key")

        let imageURL = "https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/PNG_transparency_demonstration_1.png/280px-PNG_transparency_demonstration_1.png"

        let response = try await client.responses.create(
            model: "gpt-4o",
            input: .messages([
                .user(parts: [
                    .inputText("Describe this image in detail."),
                    .inputImage(url: imageURL, detail: .high),
                ])
            ])
        )

        if let text = response.outputText {
            print("Response: \(text)")
        }
    }

    /// Sends an image via file ID using the Responses API.
    ///
    /// If you've previously uploaded an image file via the Files API,
    /// you can reference it by its file ID instead of a URL.
    ///
    /// Usage:
    /// ```swift
    /// try await MultimodalExamples.responsesWithFileId()
    /// ```
    static func responsesWithFileId() async throws {
        let client = OpenAI(apiKey: "your-api-key")

        // Upload an image file first (or use an existing file ID)
        let imageData = try Data(contentsOf: URL(fileURLWithPath: "/path/to/photo.png"))
        let file = try await client.files.create(
            file: imageData,
            filename: "photo.png",
            purpose: "vision"
        )
        print("Uploaded file: \(file.id)")

        // Reference the uploaded file by ID in the Responses API
        let response = try await client.responses.create(
            model: "gpt-4o",
            input: .messages([
                .user(parts: [
                    .inputText("What is shown in this uploaded image?"),
                    .inputImage(fileId: file.id, detail: .auto),
                ])
            ])
        )

        if let text = response.outputText {
            print("Response: \(text)")
        }
    }
}
