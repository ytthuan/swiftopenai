/// SwiftOpenAI — A Swift port of the OpenAI Python SDK.
///
/// Provides async/await-based access to all OpenAI APIs including
/// Chat Completions, Responses, Embeddings, Images, Audio, Files,
/// Fine-tuning, Models, Moderations, and more.
///
/// Usage:
/// ```swift
/// let client = OpenAI(apiKey: "sk-...")
/// let response = try await client.chat.completions.create(
///     model: "gpt-4o",
///     messages: [.user("Hello!")]
/// )
/// ```

