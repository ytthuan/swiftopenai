import Foundation
@testable import SwiftOpenAI
import Testing

private struct Candidate02DynamicEnvelope: Encodable, Sendable {
    let requestID: String
    let dynamicValues: JSONValue
}

private func candidate02ProductionEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    return encoder
}

private func candidate02CanonicalJSON(_ data: Data) throws -> Data {
    let object = try JSONSerialization.jsonObject(with: data)
    return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
}

private func candidate02ExpectedCanonicalJSON(_ fixture: String) throws -> Data {
    try candidate02CanonicalJSON(Data(fixture.utf8))
}

private struct Candidate02IndexKey: CodingKey {
    let intValue: Int?
    let stringValue: String

    init(index: Int) {
        intValue = index
        stringValue = "Index \(index)"
    }

    init?(intValue: Int) {
        self.init(index: intValue)
    }

    init?(stringValue: String) {
        return nil
    }
}

private func candidate02Indices(_ codingPath: [any CodingKey]) -> [Int] {
    codingPath.compactMap(\.intValue)
}

private enum Candidate02ContainerKind: Equatable {
    case unkeyed
    case singleValue
}

private struct Candidate02ContainerEvent: Equatable {
    let kind: Candidate02ContainerKind
    let indices: [Int]
}

private final class Candidate02RecordingState {
    var events: [Candidate02ContainerEvent] = []
}

private struct Candidate02RecordingEncoder: Encoder {
    let state: Candidate02RecordingState
    let codingPath: [any CodingKey]
    let userInfo: [CodingUserInfoKey: Any] = [:]

    init(
        state: Candidate02RecordingState,
        codingPath: [any CodingKey] = []
    ) {
        self.state = state
        self.codingPath = codingPath
    }

    func container<Key: CodingKey>(
        keyedBy type: Key.Type
    ) -> KeyedEncodingContainer<Key> {
        fatalError("JSONValue unexpectedly requested a keyed container")
    }

    func unkeyedContainer() -> any UnkeyedEncodingContainer {
        state.events.append(
            .init(kind: .unkeyed, indices: candidate02Indices(codingPath))
        )
        return Candidate02RecordingUnkeyedContainer(
            state: state,
            codingPath: codingPath
        )
    }

    func singleValueContainer() -> any SingleValueEncodingContainer {
        state.events.append(
            .init(kind: .singleValue, indices: candidate02Indices(codingPath))
        )
        return Candidate02DiscardingSingleValueContainer(codingPath: codingPath)
    }
}

private struct Candidate02RecordingUnkeyedContainer: UnkeyedEncodingContainer {
    let state: Candidate02RecordingState
    let codingPath: [any CodingKey]
    private(set) var count = 0

    mutating func encodeNil() throws {
        count += 1
    }

    mutating func encode<T: Encodable>(_ value: T) throws {
        let childPath = codingPath + [Candidate02IndexKey(index: count)]
        count += 1
        try value.encode(
            to: Candidate02RecordingEncoder(
                state: state,
                codingPath: childPath
            )
        )
    }

    mutating func nestedContainer<Key: CodingKey>(
        keyedBy keyType: Key.Type
    ) -> KeyedEncodingContainer<Key> {
        fatalError("JSONValue unexpectedly requested a nested keyed container")
    }

    mutating func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
        fatalError("JSONValue unexpectedly requested a nested unkeyed container")
    }

    mutating func superEncoder() -> any Encoder {
        fatalError("JSONValue unexpectedly requested a super encoder")
    }
}

private struct Candidate02DiscardingSingleValueContainer:
    SingleValueEncodingContainer
{
    let codingPath: [any CodingKey]

    func encodeNil() throws {}
    func encode<T: Encodable>(_ value: T) throws {}
}

private enum Candidate02SentinelError: Error, Equatable {
    case selectedNestedElement
}

private final class Candidate02ThrowingProbeState {
    let failureIndices: [Int]
    var containerEvents: [Candidate02ContainerEvent] = []
    var encodedValueIndices: [[Int]] = []

    init(failureIndices: [Int]) {
        self.failureIndices = failureIndices
    }
}

private struct Candidate02ThrowingProbeEncoder: Encoder {
    let state: Candidate02ThrowingProbeState
    let codingPath: [any CodingKey]
    let userInfo: [CodingUserInfoKey: Any] = [:]

    init(
        state: Candidate02ThrowingProbeState,
        codingPath: [any CodingKey] = []
    ) {
        self.state = state
        self.codingPath = codingPath
    }

    func container<Key: CodingKey>(
        keyedBy type: Key.Type
    ) -> KeyedEncodingContainer<Key> {
        fatalError("JSONValue unexpectedly requested a keyed container")
    }

    func unkeyedContainer() -> any UnkeyedEncodingContainer {
        state.containerEvents.append(
            .init(kind: .unkeyed, indices: candidate02Indices(codingPath))
        )
        return Candidate02ThrowingProbeUnkeyedContainer(
            state: state,
            codingPath: codingPath
        )
    }

    func singleValueContainer() -> any SingleValueEncodingContainer {
        state.containerEvents.append(
            .init(kind: .singleValue, indices: candidate02Indices(codingPath))
        )
        return Candidate02ThrowingProbeSingleValueContainer(
            state: state,
            codingPath: codingPath
        )
    }
}

private struct Candidate02ThrowingProbeUnkeyedContainer:
    UnkeyedEncodingContainer
{
    let state: Candidate02ThrowingProbeState
    let codingPath: [any CodingKey]
    private(set) var count = 0

    mutating func encodeNil() throws {
        count += 1
    }

    mutating func encode<T: Encodable>(_ value: T) throws {
        let childPath = codingPath + [Candidate02IndexKey(index: count)]
        count += 1
        try value.encode(
            to: Candidate02ThrowingProbeEncoder(
                state: state,
                codingPath: childPath
            )
        )
    }

    mutating func nestedContainer<Key: CodingKey>(
        keyedBy keyType: Key.Type
    ) -> KeyedEncodingContainer<Key> {
        fatalError("JSONValue unexpectedly requested a nested keyed container")
    }

    mutating func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
        fatalError("JSONValue unexpectedly requested a nested unkeyed container")
    }

    mutating func superEncoder() -> any Encoder {
        fatalError("JSONValue unexpectedly requested a super encoder")
    }
}

private struct Candidate02ThrowingProbeSingleValueContainer:
    SingleValueEncodingContainer
{
    let state: Candidate02ThrowingProbeState
    let codingPath: [any CodingKey]

    func encodeNil() throws {
        try recordAndThrowIfSelected()
    }

    func encode<T: Encodable>(_ value: T) throws {
        try recordAndThrowIfSelected()
    }

    private func recordAndThrowIfSelected() throws {
        let indices = candidate02Indices(codingPath)
        state.encodedValueIndices.append(indices)
        if indices == state.failureIndices {
            throw Candidate02SentinelError.selectedNestedElement
        }
    }
}

@Suite struct JSONValueCandidate02CorrectnessTests {
    @Test func candidate02NestedArraysEncodeWithExactOrderAndSemanticEquality() async throws {
        let decimalLiteral = "1234567890.1234567890123456789012345678"
        let decimal = try #require(
            Decimal(
                string: decimalLiteral,
                locale: Locale(identifier: "en_US_POSIX")
            )
        )
        let number = try #require(JSONNumber(decimal))
        let value: JSONValue = .array([
            .object([
                "values": .array([
                    .null,
                    .bool(true),
                    .string("first"),
                    .integer(Int64.min),
                    .unsignedInteger(UInt64.max),
                    .number(number),
                    .array([
                        .string("nested-first"),
                        .string("nested-second"),
                    ]),
                    .object([
                        "final": .bool(false),
                    ]),
                ]),
            ]),
            .array([
                .object(["position": .integer(2)]),
                .null,
            ]),
        ])
        let expected = """
        [
          {
            "values": [
              null,
              true,
              "first",
              -9223372036854775808,
              18446744073709551615,
              1234567890.1234567890123456789012345678,
              ["nested-first", "nested-second"],
              {"final": false}
            ]
          },
          [{"position": 2}, null]
        ]
        """

        let encoded = try candidate02ProductionEncoder().encode(value)
        #expect(
            try candidate02CanonicalJSON(encoded)
                == candidate02ExpectedCanonicalJSON(expected)
        )

        let outer = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [Any]
        )
        let firstObject = try #require(outer[0] as? [String: Any])
        let values = try #require(firstObject["values"] as? [Any])
        #expect(values.count == 8)
        #expect(values[0] is NSNull)
        #expect(values[1] as? Bool == true)
        #expect(values[2] as? String == "first")
        #expect((values[3] as? NSNumber)?.stringValue == String(Int64.min))
        #expect((values[4] as? NSNumber)?.stringValue == String(UInt64.max))
        #expect((values[5] as? NSNumber)?.decimalValue == decimal)
        #expect(
            values[6] as? [String]
                == ["nested-first", "nested-second"]
        )
        #expect((values[7] as? [String: Bool])?["final"] == false)
    }

    @Test func candidate02SnakeCaseStrategyPreservesEveryDynamicObjectKey() async throws {
        let envelope = Candidate02DynamicEnvelope(
            requestID: "request-02",
            dynamicValues: .array([
                .object([
                    "camelCase": .string("camel"),
                    "snake_case": .string("snake"),
                    "URLValue": .string("acronym"),
                    "repeated__underscores": .string("repeated"),
                    "properties": .object([
                        "userID": .string("schema-property"),
                        "$defs": .object([
                            "HTTPResponse": .string("schema-name"),
                        ]),
                    ]),
                ]),
            ])
        )
        let expected = """
        {
          "request_id": "request-02",
          "dynamic_values": [{
            "camelCase": "camel",
            "snake_case": "snake",
            "URLValue": "acronym",
            "repeated__underscores": "repeated",
            "properties": {
              "userID": "schema-property",
              "$defs": {"HTTPResponse": "schema-name"}
            }
          }]
        }
        """

        let encoded = try candidate02ProductionEncoder().encode(envelope)
        #expect(
            try candidate02CanonicalJSON(encoded)
                == candidate02ExpectedCanonicalJSON(expected)
        )
    }

    @Test func candidate02IntegerDecimalAndNonFiniteBoundariesRemainExact() async throws {
        let decimalLiteral = "0.12345678901234567890123456789012345678"
        let decimal = try #require(
            Decimal(
                string: decimalLiteral,
                locale: Locale(identifier: "en_US_POSIX")
            )
        )
        let number = try #require(JSONNumber(decimal))
        let value: JSONValue = .array([
            .integer(Int64.min),
            .unsignedInteger(UInt64.max),
            .number(number),
        ])
        let expected = """
        [
          -9223372036854775808,
          18446744073709551615,
          0.12345678901234567890123456789012345678
        ]
        """

        let encoded = try candidate02ProductionEncoder().encode(value)
        #expect(
            try candidate02CanonicalJSON(encoded)
                == candidate02ExpectedCanonicalJSON(expected)
        )
        let decodedDecimals = try JSONDecoder().decode([Decimal].self, from: encoded)
        #expect(decodedDecimals[0] == Decimal(Int64.min))
        #expect(decodedDecimals[1] == Decimal(UInt64.max))
        #expect(decodedDecimals[2] == decimal)

        #expect(JSONNumber(Decimal.nan) == nil)
        #expect(JSONNumber(Double.nan) == nil)
        #expect(JSONNumber(Double.infinity) == nil)
        #expect(JSONNumber(-Double.infinity) == nil)

        for invalidLiteral in ["1e128", "NaN", "Infinity", "-Infinity"] {
            do {
                _ = try JSONDecoder().decode(
                    JSONValue.self,
                    from: Data(invalidLiteral.utf8)
                )
                Issue.record("Expected \(invalidLiteral) to fail JSONValue decoding")
            } catch {
                // Existing non-finite and out-of-range JSON errors must remain errors.
            }
        }
    }

    @Test func candidate02ConcurrentEncodersProduceDeterministicSemantics() async throws {
        let value = Candidate02DynamicEnvelope(
            requestID: "concurrent-02",
            dynamicValues: .array([
                .object([
                    "camelCase": .array([
                        .integer(Int64.min),
                        .unsignedInteger(UInt64.max),
                        .object([
                            "schemaProperty": .array([
                                .null,
                                .bool(true),
                                .string("done"),
                            ]),
                        ]),
                    ]),
                ]),
            ])
        )
        let expected = try candidate02CanonicalJSON(
            candidate02ProductionEncoder().encode(value)
        )

        let results = try await withThrowingTaskGroup(
            of: Data.self,
            returning: [Data].self
        ) { group in
            for _ in 0..<32 {
                group.addTask {
                    try candidate02ProductionEncoder().encode(value)
                }
            }

            var outputs: [Data] = []
            for try await output in group {
                outputs.append(output)
            }
            return outputs
        }

        #expect(results.count == 32)
        for result in results {
            #expect(try candidate02CanonicalJSON(result) == expected)
        }
    }

    @Test func candidate02EmptyArraysUseExactProductionWireShape() async throws {
        let topLevel = try candidate02ProductionEncoder().encode(
            JSONValue.array([])
        )
        #expect(topLevel == Data("[]".utf8))

        let nested: JSONValue = .array([
            .array([]),
            .object(["value": .array([])]),
        ])
        let nestedData = try candidate02ProductionEncoder().encode(nested)
        let expected = """
        [[], {"value": []}]
        """
        #expect(
            try candidate02CanonicalJSON(nestedData)
                == candidate02ExpectedCanonicalJSON(expected)
        )

        let decoded = try #require(
            JSONSerialization.jsonObject(with: nestedData) as? [Any]
        )
        #expect((decoded[0] as? [Any])?.isEmpty == true)
        let object = try #require(decoded[1] as? [String: Any])
        #expect((object["value"] as? [Any])?.isEmpty == true)
    }

    @Test func candidate02RecordingEncoderProvesContainerTopologyAndArrayIndices() async throws {
        let state = Candidate02RecordingState()
        let value: JSONValue = .array([
            .array([.string("leaf")]),
            .object(["value": .array([])]),
            .array([]),
        ])

        try value.encode(to: Candidate02RecordingEncoder(state: state))

        #expect(state.events == [
            .init(kind: .unkeyed, indices: []),
            .init(kind: .unkeyed, indices: [0]),
            .init(kind: .singleValue, indices: [0, 0]),
            .init(kind: .singleValue, indices: [1]),
            .init(kind: .unkeyed, indices: [2]),
        ])

        let objectState = Candidate02RecordingState()
        try JSONValue.object(["value": .array([])]).encode(
            to: Candidate02RecordingEncoder(state: objectState)
        )
        #expect(objectState.events == [
            .init(kind: .singleValue, indices: []),
        ])

        let emptyState = Candidate02RecordingState()
        try JSONValue.array([]).encode(
            to: Candidate02RecordingEncoder(state: emptyState)
        )
        #expect(emptyState.events == [
            .init(kind: .unkeyed, indices: []),
        ])
    }

    @Test func candidate02ThrowingProbePreservesSentinelAndExactNestedPath() async throws {
        let state = Candidate02ThrowingProbeState(
            failureIndices: [1, 1, 1]
        )
        let value: JSONValue = .array([
            .string("before"),
            .array([
                .string("middle"),
                .array([
                    .string("nested-before"),
                    .string("selected"),
                    .string("never-encoded"),
                ]),
            ]),
        ])

        do {
            try value.encode(to: Candidate02ThrowingProbeEncoder(state: state))
            Issue.record("Expected the selected nested element to throw")
        } catch let error as Candidate02SentinelError {
            #expect(error == .selectedNestedElement)
        } catch {
            Issue.record("Expected sentinel error, received \(type(of: error))")
        }

        #expect(state.containerEvents == [
            .init(kind: .unkeyed, indices: []),
            .init(kind: .singleValue, indices: [0]),
            .init(kind: .unkeyed, indices: [1]),
            .init(kind: .singleValue, indices: [1, 0]),
            .init(kind: .unkeyed, indices: [1, 1]),
            .init(kind: .singleValue, indices: [1, 1, 0]),
            .init(kind: .singleValue, indices: [1, 1, 1]),
        ])
        #expect(state.encodedValueIndices == [
            [0],
            [1, 0],
            [1, 1, 0],
            [1, 1, 1],
        ])
    }

    @Test func candidate02ResponsesWebSocketWireCarriesNestedDynamicArrays() async throws {
        let request = ResponseCreateRequest(
            model: "gpt-candidate-02",
            input: .init(jsonValue: .array([
                .object([
                    "type": .string("message"),
                    "role": .string("user"),
                    "content": .array([
                        .object([
                            "type": .string("input_text"),
                            "dynamicValues": .array([
                                .array([.string("first"), .null]),
                                .object([
                                    "schemaProperty": .array([
                                        .bool(false),
                                        .integer(7),
                                    ]),
                                ]),
                            ]),
                        ]),
                    ]),
                ]),
            ]))
        )
        let payload = ResponseWebSocketCreateRequest(request: request)
        let expected = """
        {
          "type": "response.create",
          "model": "gpt-candidate-02",
          "input": [{
            "type": "message",
            "role": "user",
            "content": [{
              "type": "input_text",
              "dynamicValues": [
                ["first", null],
                {"schemaProperty": [false, 7]}
              ]
            }]
          }]
        }
        """

        let encoded = try candidate02ProductionEncoder().encode(payload)
        #expect(
            try candidate02CanonicalJSON(encoded)
                == candidate02ExpectedCanonicalJSON(expected)
        )
    }
}

extension MockAPITests {
    @Test func candidate02ChatWireFixturesCarryNestedDynamicArrays() async throws {
        let request = ChatCompletionRequest(
            model: "gpt-candidate-02",
            messages: [
                .init(jsonValue: .object([
                    "role": .string("user"),
                    "content": .array([
                        .object([
                            "type": .string("candidate02"),
                            "schemaProperties": .array([
                                .object([
                                    "camelCase": .string("first"),
                                    "nested": .array([.bool(true), .null]),
                                ]),
                                .array([
                                    .string("second"),
                                    .integer(-2),
                                ]),
                            ]),
                        ]),
                    ]),
                ])),
            ]
        )
        let expectedCreate = """
        {
          "model": "gpt-candidate-02",
          "messages": [{
            "role": "user",
            "content": [{
              "type": "candidate02",
              "schemaProperties": [
                {"camelCase": "first", "nested": [true, null]},
                ["second", -2]
              ]
            }]
          }]
        }
        """
        let expectedStream = """
        {
          "model": "gpt-candidate-02",
          "messages": [{
            "role": "user",
            "content": [{
              "type": "candidate02",
              "schemaProperties": [
                {"camelCase": "first", "nested": [true, null]},
                ["second", -2]
              ]
            }]
          }],
          "stream": true
        }
        """

        MockURLProtocol.reset()
        var client = makeMockClient(json: candidate02ChatResponseFixture)
        _ = try await client.chat.completions.create(request: request)
        let createBody = try #require(MockURLProtocol.lastRequestBody)
        #expect(
            try candidate02CanonicalJSON(createBody)
                == candidate02ExpectedCanonicalJSON(expectedCreate)
        )

        MockURLProtocol.reset()
        client = makeMockClient(json: "data: [DONE]\n\n")
        _ = try await client.chat.completions.createStream(request: request)
        let streamBody = try #require(MockURLProtocol.lastRequestBody)
        #expect(
            try candidate02CanonicalJSON(streamBody)
                == candidate02ExpectedCanonicalJSON(expectedStream)
        )
    }

    @Test func candidate02ResponsesWireFixturesCarryNestedDynamicArrays() async throws {
        let request = ResponseCreateRequest(
            model: "gpt-candidate-02",
            input: .init(jsonValue: .array([
                .object([
                    "type": .string("message"),
                    "role": .string("user"),
                    "content": .array([
                        .object([
                            "type": .string("input_text"),
                            "dynamicValues": .array([
                                .array([
                                    .string("first"),
                                    .null,
                                ]),
                                .object([
                                    "schemaProperty": .array([
                                        .bool(false),
                                        .integer(7),
                                    ]),
                                ]),
                            ]),
                        ]),
                    ]),
                ]),
            ]))
        )
        let expectedCreate = """
        {
          "model": "gpt-candidate-02",
          "input": [{
            "type": "message",
            "role": "user",
            "content": [{
              "type": "input_text",
              "dynamicValues": [
                ["first", null],
                {"schemaProperty": [false, 7]}
              ]
            }]
          }]
        }
        """
        let expectedStream = """
        {
          "model": "gpt-candidate-02",
          "input": [{
            "type": "message",
            "role": "user",
            "content": [{
              "type": "input_text",
              "dynamicValues": [
                ["first", null],
                {"schemaProperty": [false, 7]}
              ]
            }]
          }],
          "stream": true
        }
        """

        MockURLProtocol.reset()
        var client = makeMockClient(json: candidate02ResponseFixture)
        _ = try await client.responses.create(request: request)
        let createBody = try #require(MockURLProtocol.lastRequestBody)
        #expect(
            try candidate02CanonicalJSON(createBody)
                == candidate02ExpectedCanonicalJSON(expectedCreate)
        )

        MockURLProtocol.reset()
        client = makeMockClient(json: "data: [DONE]\n\n")
        _ = try await client.responses.createStream(request: request)
        let streamBody = try #require(MockURLProtocol.lastRequestBody)
        #expect(
            try candidate02CanonicalJSON(streamBody)
                == candidate02ExpectedCanonicalJSON(expectedStream)
        )
    }

    private var candidate02ChatResponseFixture: String {
        """
        {
          "id": "chat_candidate_02",
          "object": "chat.completion",
          "created": 1,
          "model": "gpt-candidate-02",
          "choices": [{
            "index": 0,
            "message": {"role": "assistant", "content": "ok"},
            "finish_reason": "stop"
          }]
        }
        """
    }

    private var candidate02ResponseFixture: String {
        """
        {
          "id": "resp_candidate_02",
          "object": "response",
          "created_at": 1,
          "model": "gpt-candidate-02",
          "output": [],
          "status": "completed"
        }
        """
    }
}
