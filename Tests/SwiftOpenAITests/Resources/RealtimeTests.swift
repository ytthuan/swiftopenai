import Foundation
import Testing
@testable import SwiftOpenAI

@Suite struct RealtimeTests {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    @Test func realtimeSessionConfigEncodes() throws {
        let config = RealtimeSessionConfig(
            model: "gpt-realtime",
            instructions: "Be concise",
            modalities: ["text", "audio"],
            audio: RealtimeAudioConfig(
                input: RealtimeAudioInput(format: "pcm16"),
                output: RealtimeAudioOutput(format: "pcm16", voice: "alloy")
            ),
            toolChoice: "auto",
            temperature: 0.7,
            maxOutputTokens: .count(256),
            turnDetection: RealtimeTurnDetection(
                type: "server_vad",
                threshold: 0.5,
                prefixPaddingMs: 120,
                silenceDurationMs: 400,
                createResponse: true
            )
        )

        let data = try encoder.encode(config)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let turnDetection = try #require(json["turn_detection"] as? [String: Any])

        #expect(json["type"] as? String == "realtime")
        #expect(json["model"] as? String == "gpt-realtime")
        #expect(json["max_response_output_tokens"] as? Int == 256)
        #expect(turnDetection["prefix_padding_ms"] as? Int == 120)
    }

    @Test func realtimeSessionConfigDecodes() throws {
        let json = """
        {
          "type": "realtime",
          "model": "gpt-realtime",
          "instructions": "Use tools when needed",
          "modalities": ["text", "audio"],
          "audio": {
            "input": {"format": "pcm16"},
            "output": {"format": "pcm16", "voice": "alloy"}
          },
          "tool_choice": "auto",
          "temperature": 0.9,
          "max_response_output_tokens": "inf",
          "turn_detection": {
            "type": "server_vad",
            "threshold": 0.4,
            "prefix_padding_ms": 150,
            "silence_duration_ms": 350,
            "create_response": false
          }
        }
        """

        let config = try decoder.decode(RealtimeSessionConfig.self, from: Data(json.utf8))
        #expect(config.model == "gpt-realtime")
        #expect(config.toolChoice == "auto")
        #expect(config.turnDetection?.silenceDurationMs == 350)
        if case .infinite? = config.maxOutputTokens {
            #expect(true)
        } else {
            #expect(Bool(false))
        }
    }

    @Test func realtimeClientEventSessionUpdateEncodes() throws {
        let event = RealtimeClientEvent.sessionUpdate(
            RealtimeSessionUpdateEvent(
                session: RealtimeSessionConfig(model: "gpt-realtime"),
                eventId: "evt_session"
            )
        )

        let data = try encoder.encode(event)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let session = try #require(json["session"] as? [String: Any])

        #expect(json["type"] as? String == "session.update")
        #expect(json["event_id"] as? String == "evt_session")
        #expect(session["model"] as? String == "gpt-realtime")
    }

    @Test func realtimeClientEventConversationItemCreateEncodes() throws {
        let item = RealtimeConversationItem(
            id: "item_1",
            type: "message",
            role: "user",
            content: [RealtimeContentPart(type: "input_text", text: "Hello")]
        )
        let event = RealtimeClientEvent.conversationItemCreate(
            RealtimeConversationItemCreateEvent(item: item, previousItemId: "item_0", eventId: "evt_item")
        )

        let data = try encoder.encode(event)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let encodedItem = try #require(json["item"] as? [String: Any])

        #expect(json["type"] as? String == "conversation.item.create")
        #expect(json["previous_item_id"] as? String == "item_0")
        #expect(encodedItem["type"] as? String == "message")
    }

    @Test func realtimeClientEventResponseCreateEncodes() throws {
        let event = RealtimeClientEvent.responseCreate(
            RealtimeResponseCreateEvent(
                response: RealtimeResponseConfig(
                    modalities: ["text"],
                    instructions: "Answer briefly",
                    maxOutputTokens: .count(42)
                ),
                eventId: "evt_response"
            )
        )

        let data = try encoder.encode(event)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let response = try #require(json["response"] as? [String: Any])

        #expect(json["type"] as? String == "response.create")
        #expect(json["event_id"] as? String == "evt_response")
        #expect(response["max_response_output_tokens"] as? Int == 42)
    }

    @Test func realtimeClientEventInputAudioBufferAppendEncodes() throws {
        let event = RealtimeClientEvent.inputAudioBufferAppend(
            RealtimeInputAudioBufferAppendEvent(audio: "YmFzZTY0", eventId: "evt_audio")
        )

        let data = try encoder.encode(event)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["type"] as? String == "input_audio_buffer.append")
        #expect(json["audio"] as? String == "YmFzZTY0")
        #expect(json["event_id"] as? String == "evt_audio")
    }

    @Test func realtimeServerEventSessionCreatedDecodes() throws {
        let json = """
        {
          "type": "session.created",
          "event_id": "server_evt_1",
          "session": {
            "id": "sess_123",
            "object": "realtime.session",
            "model": "gpt-realtime",
            "modalities": ["text", "audio"],
            "instructions": "Be concise",
            "voice": "alloy",
             "max_response_output_tokens": 200
          }
        }
        """

        let event = try decoder.decode(RealtimeServerEvent.self, from: Data(json.utf8))
        #expect(event.type == "session.created")
        #expect(event.eventId == "server_evt_1")
        #expect(event.session?.id == "sess_123")
        if case .count(200)? = event.session?.maxOutputTokens {
            #expect(true)
        } else {
            #expect(Bool(false))
        }
    }

    @Test func realtimeServerEventOutputTextDeltaDecodes() throws {
        let json = """
        {
          "type": "response.output_text.delta",
          "event_id": "server_evt_2",
          "response_id": "resp_1",
          "item_id": "item_1",
          "output_index": 0,
          "content_index": 0,
          "delta": "Hel"
        }
        """

        let event = try decoder.decode(RealtimeServerEvent.self, from: Data(json.utf8))
        #expect(event.type == "response.output_text.delta")
        #expect(event.responseId == "resp_1")
        #expect(event.outputIndex == 0)
        #expect(event.delta == "Hel")
    }

    @Test func realtimeServerEventResponseDoneDecodes() throws {
        let json = """
        {
          "type": "response.done",
          "event_id": "server_evt_3",
          "response": {
            "id": "resp_done",
            "object": "realtime.response",
            "status": "completed",
            "output": [{"type": "message", "role": "assistant"}]
          }
        }
        """

        let event = try decoder.decode(RealtimeServerEvent.self, from: Data(json.utf8))
        #expect(event.type == "response.done")
        #expect(event.response?.id == "resp_done")
        #expect(event.response?.status == "completed")
        #expect(event.response?.output?.first?.role == "assistant")
    }

    @Test func realtimeServerEventErrorDecodes() throws {
        let json = """
        {
          "type": "error",
          "event_id": "server_evt_4",
          "error": {
            "type": "invalid_request_error",
            "code": "bad_request",
            "message": "Invalid payload",
            "param": "response"
          }
        }
        """

        let event = try decoder.decode(RealtimeServerEvent.self, from: Data(json.utf8))
        #expect(event.type == "error")
        #expect(event.error?.type == "invalid_request_error")
        #expect(event.error?.code == "bad_request")
        #expect(event.error?.param == "response")
    }

    @Test func realtimeConversationItemEncodes() throws {
        let item = RealtimeConversationItem(
            id: "item_call",
            type: "function_call",
            callId: "call_123",
            name: "get_weather",
            arguments: "{\"city\":\"Tokyo\"}"
        )

        let data = try encoder.encode(item)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["id"] as? String == "item_call")
        #expect(json["type"] as? String == "function_call")
        #expect(json["call_id"] as? String == "call_123")
        #expect(json["arguments"] as? String == "{\"city\":\"Tokyo\"}")
    }

    @Test func realtimeConversationItemDecodes() throws {
        let json = """
        {
          "id": "item_msg",
          "object": "realtime.item",
          "type": "message",
          "status": "completed",
          "role": "assistant",
          "content": [{"type": "output_text", "text": "Hi there"}]
        }
        """

        let item = try decoder.decode(RealtimeConversationItem.self, from: Data(json.utf8))
        #expect(item.id == "item_msg")
        #expect(item.object == "realtime.item")
        #expect(item.status == "completed")
        #expect(item.content?.first?.text == "Hi there")
    }

    @Test func realtimeMaxTokensIntegerEncodesAndDecodes() throws {
        struct Wrapper: Codable {
            let value: RealtimeMaxTokens
        }

        let encoded = try encoder.encode(Wrapper(value: .count(1024)))
        let encodedJSON = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let encodedValue = encodedJSON["value"] as? Int
        let decoded = try decoder.decode(Wrapper.self, from: Data("{\"value\":1024}".utf8)).value

        #expect(encodedValue == 1024)
        if case .count(1024) = decoded {
            #expect(true)
        } else {
            #expect(Bool(false))
        }
    }

    @Test func realtimeMaxTokensInfiniteEncodesAndDecodes() throws {
        struct Wrapper: Codable {
            let value: RealtimeMaxTokens
        }

        let encoded = try encoder.encode(Wrapper(value: .infinite))
        let encodedJSON = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let encodedValue = encodedJSON["value"] as? String
        let decoded = try decoder.decode(Wrapper.self, from: Data("{\"value\":\"inf\"}".utf8)).value

        #expect(encodedValue == "inf")
        if case .infinite = decoded {
            #expect(true)
        } else {
            #expect(Bool(false))
        }
    }

    @Test func realtimeToolEncodesWithParameters() throws {
        let parameters: [String: AnyCodable] = [
            "type": AnyCodable("object"),
            "properties": AnyCodable([
                "location": AnyCodable(["type": AnyCodable("string")] as [String: AnyCodable])
            ] as [String: AnyCodable]),
            "required": AnyCodable([AnyCodable("location")])
        ]
        let tool = RealtimeTool(
            name: "get_weather",
            description: "Get weather for a location",
            parameters: AnyCodable(parameters)
        )

        let data = try encoder.encode(tool)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let encodedParameters = try #require(json["parameters"] as? [String: Any])
        let properties = try #require(encodedParameters["properties"] as? [String: Any])

        #expect(json["type"] as? String == "function")
        #expect(json["name"] as? String == "get_weather")
        #expect(encodedParameters["type"] as? String == "object")
        #expect(properties["location"] != nil)
    }
}
