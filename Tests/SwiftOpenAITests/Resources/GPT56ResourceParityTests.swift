import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import SwiftOpenAI

extension MockAPITests {
    private func capturedBody() throws -> [String: Any] {
        let data = try #require(MockURLProtocol.lastRequestBody)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func chatFixture(model: String) -> String {
        """
        {
          "id":"chat_123",
          "object":"chat.completion",
          "created":123,
          "model":"\(model)",
          "choices":[{
            "index":0,
            "message":{"role":"assistant","content":"ok"},
            "finish_reason":"stop"
          }]
        }
        """
    }

    private func responseFixture(model: String) -> String {
        """
        {
          "id":"resp_123",
          "object":"response",
          "created_at":123,
          "model":"\(model)",
          "output":[],
          "status":"completed"
        }
        """
    }

    private var compactFixture: String {
        """
        {
          "id":"resp_compact",
          "object":"response.compaction",
          "created_at":123,
          "output":[{
            "type":"compaction",
            "encrypted_content":"enc_compacted",
            "created_by":"service"
          }]
        }
        """
    }

    @Test func gpt56ModelStringsReachEveryHTTPParityEndpointUnchanged() async throws {
        for model in ["gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna"] {
            MockURLProtocol.reset()
            var client = makeMockClient(json: chatFixture(model: model))
            _ = try await client.chat.completions.create(request: .init(
                model: model,
                messages: [.user(parts: [.text("hello")])]
            ))
            #expect(MockURLProtocol.lastRequest?.url?.path == "/v1/chat/completions")
            let chatCreateBody = try capturedBody()
            #expect(chatCreateBody["model"] as? String == model)

            MockURLProtocol.reset()
            client = makeMockClient(json: "data: [DONE]\n\n")
            _ = try await client.chat.completions.createStream(request: .init(
                model: model,
                messages: [.user(parts: [.text("hello")])]
            ))
            #expect(MockURLProtocol.lastRequest?.url?.path == "/v1/chat/completions")
            let chatStreamBody = try capturedBody()
            #expect(chatStreamBody["model"] as? String == model)
            #expect(chatStreamBody["stream"] as? Bool == true)

            MockURLProtocol.reset()
            client = makeMockClient(json: responseFixture(model: model))
            _ = try await client.responses.create(request: .init(
                model: model,
                input: .text("hello")
            ))
            #expect(MockURLProtocol.lastRequest?.url?.path == "/v1/responses")
            let responseCreateBody = try capturedBody()
            #expect(responseCreateBody["model"] as? String == model)

            MockURLProtocol.reset()
            client = makeMockClient(json: "data: [DONE]\n\n")
            _ = try await client.responses.createStream(request: .init(
                model: model,
                input: .text("hello")
            ))
            #expect(MockURLProtocol.lastRequest?.url?.path == "/v1/responses")
            let responseStreamBody = try capturedBody()
            #expect(responseStreamBody["model"] as? String == model)
            #expect(responseStreamBody["stream"] as? Bool == true)

            MockURLProtocol.reset()
            client = makeMockClient(json: compactFixture)
            let compacted = try await client.responses.compact(request: .init(
                model: model,
                input: .text("hello")
            ))
            #expect(MockURLProtocol.lastRequest?.url?.path == "/v1/responses/compact")
            let compactBody = try capturedBody()
            #expect(compactBody["model"] as? String == model)
            #expect(compacted.output.first?.encryptedContent == "enc_compacted")
            #expect(compacted.output.first?.createdBy == "service")
        }
    }

    @Test func chatResourceOverloadsPreserveCreateNilAndStreamTrueSemantics() async throws {
        MockURLProtocol.reset()
        var client = makeMockClient(json: chatFixture(model: "gpt-5.6-sol"))
        _ = try await client.chat.completions.create(
            model: "gpt-5.6-sol",
            messages: [.user("hello")]
        )
        let legacyCreateBody = try capturedBody()
        #expect(legacyCreateBody["model"] as? String == "gpt-5.6-sol")
        #expect(legacyCreateBody["stream"] == nil)

        MockURLProtocol.reset()
        client = makeMockClient(json: "data: [DONE]\n\n")
        _ = try await client.chat.completions.createStream(
            model: "gpt-5.6-sol",
            messages: [.user("hello")]
        )
        let legacyStreamBody = try capturedBody()
        #expect(legacyStreamBody["model"] as? String == "gpt-5.6-sol")
        #expect(legacyStreamBody["stream"] as? Bool == true)

        let bridgedParams = ChatCompletionCreateParams(
            model: "gpt-5.6-sol",
            messages: [.user("hello")],
            temperature: 0.2,
            stream: true
        )
        let request = ChatCompletionRequest(bridgedParams)

        MockURLProtocol.reset()
        client = makeMockClient(json: chatFixture(model: "gpt-5.6-sol"))
        _ = try await client.chat.completions.create(request: request)
        let requestCreateBody = try capturedBody()
        #expect(requestCreateBody["stream"] == nil)
        #expect(requestCreateBody["temperature"] as? Double == 0.2)
        #expect(requestCreateBody["parameters"] == nil)
        #expect(requestCreateBody["options"] == nil)

        MockURLProtocol.reset()
        client = makeMockClient(json: "data: [DONE]\n\n")
        _ = try await client.chat.completions.createStream(request: request)
        let requestStreamBody = try capturedBody()
        #expect(requestStreamBody["stream"] as? Bool == true)
        #expect(requestStreamBody["temperature"] as? Double == 0.2)
        #expect(requestStreamBody["parameters"] == nil)
        #expect(requestStreamBody["options"] == nil)
    }

    @Test func responseResourceOverloadsPreserveCreateNilAndStreamTrueSemantics() async throws {
        MockURLProtocol.reset()
        var client = makeMockClient(json: responseFixture(model: "gpt-5.6-terra"))
        _ = try await client.responses.create(
            model: "gpt-5.6-terra",
            input: .text("hello")
        )
        let legacyCreateBody = try capturedBody()
        #expect(legacyCreateBody["model"] as? String == "gpt-5.6-terra")
        #expect(legacyCreateBody["stream"] == nil)

        MockURLProtocol.reset()
        client = makeMockClient(json: "data: [DONE]\n\n")
        _ = try await client.responses.createStream(
            model: "gpt-5.6-terra",
            input: .text("hello")
        )
        let legacyStreamBody = try capturedBody()
        #expect(legacyStreamBody["model"] as? String == "gpt-5.6-terra")
        #expect(legacyStreamBody["stream"] as? Bool == true)

        let request = ResponseCreateRequest(
            model: "gpt-5.6-terra",
            input: .text("hello"),
            options: .init(
                temperature: 0.3,
                promptCacheOptions: .init(mode: .explicit, ttl: .m30)
            )
        )

        MockURLProtocol.reset()
        client = makeMockClient(json: responseFixture(model: "gpt-5.6-terra"))
        _ = try await client.responses.create(request: request)
        let requestCreateBody = try capturedBody()
        #expect(requestCreateBody["stream"] == nil)
        #expect(requestCreateBody["temperature"] as? Double == 0.3)
        #expect(requestCreateBody["options"] == nil)
        #expect(requestCreateBody["parameters"] == nil)

        MockURLProtocol.reset()
        client = makeMockClient(json: "data: [DONE]\n\n")
        _ = try await client.responses.createStream(request: request)
        let requestStreamBody = try capturedBody()
        #expect(requestStreamBody["stream"] as? Bool == true)
        #expect(requestStreamBody["temperature"] as? Double == 0.3)
        #expect(requestStreamBody["options"] == nil)
        #expect(requestStreamBody["parameters"] == nil)
    }

    @Test func compactHTTPBodyIncludesCacheFieldsAndOmitsReasoning() async throws {
        MockURLProtocol.reset()
        let client = makeMockClient(json: compactFixture)
        _ = try await client.responses.compact(request: .init(
            model: "gpt-5.6-luna",
            input: .items([
                .init(compaction: .init(encryptedContent: "enc_previous"))
            ]),
            promptCacheKey: "cache_key",
            promptCacheOptions: .init(mode: .explicit, ttl: .m30),
            promptCacheRetention: .h24
        ))

        let body = try capturedBody()
        #expect(body["model"] as? String == "gpt-5.6-luna")
        #expect(body["prompt_cache_key"] as? String == "cache_key")
        #expect(body["prompt_cache_retention"] as? String == "24h")
        #expect(body["reasoning"] == nil)
        #expect(body["cache_control"] == nil)
        let options = try #require(body["prompt_cache_options"] as? [String: Any])
        #expect(options["mode"] as? String == "explicit")
        #expect(options["ttl"] as? String == "30m")
    }
}
