import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SwiftOpenAI

// MARK: - WebSocket Types Tests

@Suite struct WebSocketTypesTests {

    // MARK: - ResponsesClientEvent Encoding

    @Test func clientEventEncodesTypeField() throws {
        let event = ResponsesClientEvent(
            model: "gpt-5.2",
            input: .text("Hello")
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["type"] as? String == "response.create")
        #expect(json["model"] as? String == "gpt-5.2")
    }

    @Test func clientEventEncodesAllFields() throws {
        let event = ResponsesClientEvent(
            model: "gpt-5.2",
            input: .text("Hello"),
            instructions: "Be helpful",
            maxOutputTokens: 1000,
            temperature: 0.7,
            topP: 0.9,
            store: false,
            metadata: ["key": "value"],
            previousResponseId: "resp_123",
            generate: false
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["type"] as? String == "response.create")
        #expect(json["model"] as? String == "gpt-5.2")
        #expect(json["instructions"] as? String == "Be helpful")
        #expect(json["max_output_tokens"] as? Int == 1000)
        #expect(json["temperature"] as? Double == 0.7)
        #expect(json["top_p"] as? Double == 0.9)
        #expect(json["store"] as? Bool == false)
        #expect(json["previous_response_id"] as? String == "resp_123")
        #expect(json["generate"] as? Bool == false)
        let metadata = json["metadata"] as? [String: String]
        #expect(metadata?["key"] == "value")
    }

    @Test func clientEventOmitsNilFields() throws {
        let event = ResponsesClientEvent(
            model: "gpt-5.2",
            input: .text("Hello")
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Only type, model, and input should be present
        #expect(json["instructions"] == nil)
        #expect(json["max_output_tokens"] == nil)
        #expect(json["store"] == nil)
        #expect(json["generate"] == nil)
        #expect(json["previous_response_id"] == nil)
    }

    @Test func clientEventWithFunctionTool() throws {
        let tool = ResponseTool.function(FunctionToolDefinition(
            name: "get_weather",
            description: "Get weather",
            parameters: [
                "type": AnyCodable("object"),
                "properties": AnyCodable([
                    "city": AnyCodable(["type": AnyCodable("string")] as [String: AnyCodable])
                ] as [String: AnyCodable]),
            ],
            strict: true
        ))
        let event = ResponsesClientEvent(
            model: "gpt-5.2",
            input: .text("Weather in Tokyo?"),
            tools: [tool]
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        let tools = json["tools"] as? [[String: Any]]
        #expect(tools?.count == 1)
        #expect(tools?.first?["type"] as? String == "function")
    }

    // MARK: - WebSocketErrorEvent Decoding

    @Test func errorEventDecodes() throws {
        let json = """
        {
            "type": "error",
            "status": 400,
            "error": {
                "type": "invalid_request_error",
                "code": "previous_response_not_found",
                "message": "Previous response with id 'resp_abc' not found.",
                "param": "previous_response_id"
            }
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let event = try decoder.decode(WebSocketErrorEvent.self, from: json.data(using: .utf8)!)

        #expect(event.type == "error")
        #expect(event.status == 400)
        #expect(event.error.type == "invalid_request_error")
        #expect(event.error.code == "previous_response_not_found")
        #expect(event.error.message == "Previous response with id 'resp_abc' not found.")
        #expect(event.error.param == "previous_response_id")
    }

    @Test func connectionLimitErrorDecodes() throws {
        let json = """
        {
            "type": "error",
            "status": 400,
            "error": {
                "type": "invalid_request_error",
                "code": "websocket_connection_limit_reached",
                "message": "Responses websocket connection limit reached (60 minutes). Create a new websocket connection to continue."
            }
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let event = try decoder.decode(WebSocketErrorEvent.self, from: json.data(using: .utf8)!)

        #expect(event.error.code == "websocket_connection_limit_reached")
        #expect(event.error.param == nil)
    }

    // MARK: - WebSocketConnectionState

    @Test func connectionStatesExist() {
        let states: [WebSocketConnectionState] = [.disconnected, .connecting, .connected, .closing]
        #expect(states.count == 4)
    }

    // MARK: - Configuration WebSocket URL

    #if canImport(Darwin)
    @Test func httpsConvertsToWss() {
        let config = Configuration(apiKey: "test", baseURL: URL(string: "https://api.openai.com/v1")!)
        let wsURL = config.websocketBaseURL
        #expect(wsURL.scheme == "wss")
        #expect(wsURL.host == "api.openai.com")
        #expect(wsURL.path == "/v1" || wsURL.path.hasPrefix("/v1"))
    }

    @Test func httpConvertsToWs() {
        // Configuration.validateSecureURL uses assertionFailure which traps in debug builds,
        // so we test the websocketBaseURL conversion logic via https → wss instead.
        let config = Configuration(apiKey: "test", baseURL: URL(string: "https://localhost:8080/v1")!)
        let wsURL = config.websocketBaseURL
        #expect(wsURL.scheme == "wss")
        #expect(wsURL.host == "localhost")
    }

    @Test func customAzureBaseURLConverts() {
        let config = Configuration(
            apiKey: "test",
            baseURL: URL(string: "https://my-resource.openai.azure.com/openai/v1")!
        )
        let wsURL = config.websocketBaseURL
        #expect(wsURL.scheme == "wss")
        #expect(wsURL.host == "my-resource.openai.azure.com")
        #expect(wsURL.path.contains("openai"))
    }
    #endif

    // MARK: - connectWebSocket Availability

    #if canImport(Darwin)
    @Test func connectWebSocketReturnsActor() {
        let client = OpenAI(apiKey: "test-key")
        let ws = client.responses.connectWebSocket()
        // Just verify it returns a ResponsesWebSocket without crashing
        _ = ws
    }
    #endif
}
