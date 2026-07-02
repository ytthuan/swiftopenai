import Testing
import Foundation
@testable import SwiftOpenAI

/// Tests that token-usage types surface prompt-cache details (`cached_tokens`)
/// and the sibling token breakdowns, mirroring the Python SDK.
@Suite struct UsageCachedTokensTests {

    private func snakeCaseDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    // MARK: - Chat / Completions shared Usage

    @Test func usageDecodesPromptCachedTokens() throws {
        let json = """
        {
            "prompt_tokens": 100,
            "completion_tokens": 20,
            "total_tokens": 120,
            "prompt_tokens_details": {
                "cached_tokens": 64,
                "audio_tokens": 8
            },
            "completion_tokens_details": {
                "reasoning_tokens": 12,
                "audio_tokens": 0,
                "accepted_prediction_tokens": 3,
                "rejected_prediction_tokens": 1
            }
        }
        """
        let usage = try snakeCaseDecoder().decode(Usage.self, from: json.data(using: .utf8)!)
        #expect(usage.promptTokens == 100)
        #expect(usage.completionTokens == 20)
        #expect(usage.totalTokens == 120)
        #expect(usage.promptTokensDetails?.cachedTokens == 64)
        #expect(usage.promptTokensDetails?.audioTokens == 8)
        #expect(usage.completionTokensDetails?.reasoningTokens == 12)
        #expect(usage.completionTokensDetails?.audioTokens == 0)
        #expect(usage.completionTokensDetails?.acceptedPredictionTokens == 3)
        #expect(usage.completionTokensDetails?.rejectedPredictionTokens == 1)
    }

    @Test func usageDecodesWithoutDetailsRemainsNil() throws {
        let json = """
        { "prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15 }
        """
        let usage = try snakeCaseDecoder().decode(Usage.self, from: json.data(using: .utf8)!)
        #expect(usage.promptTokensDetails == nil)
        #expect(usage.completionTokensDetails == nil)
    }

    @Test func chatCompletionExposesCachedTokens() throws {
        let json = """
        {
            "id": "chatcmpl-cache",
            "object": "chat.completion",
            "created": 1700000000,
            "model": "gpt-4o",
            "choices": [],
            "usage": {
                "prompt_tokens": 2048,
                "completion_tokens": 16,
                "total_tokens": 2064,
                "prompt_tokens_details": { "cached_tokens": 1920 }
            }
        }
        """
        let completion = try snakeCaseDecoder().decode(ChatCompletion.self, from: json.data(using: .utf8)!)
        #expect(completion.usage?.promptTokensDetails?.cachedTokens == 1920)
    }

    // MARK: - Responses ResponseUsage

    @Test func responseUsageDecodesInputCachedTokens() throws {
        let json = """
        {
            "input_tokens": 500,
            "output_tokens": 40,
            "total_tokens": 540,
            "input_tokens_details": { "cached_tokens": 384 },
            "output_tokens_details": { "reasoning_tokens": 24 }
        }
        """
        let usage = try snakeCaseDecoder().decode(ResponseUsage.self, from: json.data(using: .utf8)!)
        #expect(usage.inputTokens == 500)
        #expect(usage.outputTokens == 40)
        #expect(usage.totalTokens == 540)
        #expect(usage.inputTokensDetails?.cachedTokens == 384)
        #expect(usage.outputTokensDetails?.reasoningTokens == 24)
    }

    @Test func responseUsageDecodesWithoutInputDetailsRemainsNil() throws {
        let json = """
        { "input_tokens": 10, "output_tokens": 5, "total_tokens": 15 }
        """
        let usage = try snakeCaseDecoder().decode(ResponseUsage.self, from: json.data(using: .utf8)!)
        #expect(usage.inputTokensDetails == nil)
    }

    // MARK: - Round-trip

    @Test func usageRoundTripPreservesCachedTokens() throws {
        let original = Usage(
            promptTokens: 100,
            completionTokens: 20,
            totalTokens: 120,
            promptTokensDetails: Usage.PromptTokensDetails(cachedTokens: 64)
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(original)
        let decoded = try snakeCaseDecoder().decode(Usage.self, from: data)
        #expect(decoded.promptTokensDetails?.cachedTokens == 64)
    }
}
