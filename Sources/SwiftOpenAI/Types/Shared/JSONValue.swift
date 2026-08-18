import Foundation

/// A Foundation `Decimal`-backed JSON number.
///
/// `JSONNumber` stores the numerical value as Foundation `Decimal`, which supports
/// structured numeric values using Foundation Decimal semantics. Generic `Decoder`
/// does not expose the source number token, so decoding does not preserve lexical
/// spelling such as exponent form or trailing zeros. It also does not promise
/// precision or out-of-range rejection beyond the `Decimal` implementation used by
/// the encoder and decoder.
public struct JSONNumber: Codable, Sendable, Equatable {
    /// The represented base-10 value.
    public let decimalValue: Decimal

    /// Creates a JSON number from a representable finite decimal value.
    ///
    /// - Returns: `nil` when `decimalValue` is NaN.
    public init?(_ decimalValue: Decimal) {
        guard !decimalValue.isNaN else { return nil }
        self.decimalValue = decimalValue
    }

    /// Creates a JSON number from a finite binary floating-point value.
    ///
    /// Conversion uses Foundation `Decimal` semantics and may round the original
    /// binary value. Returns `nil` for NaN, infinity, or a value that Foundation
    /// cannot represent as a finite `Decimal`.
    public init?(_ doubleValue: Double) {
        guard doubleValue.isFinite else { return nil }
        let decimalValue = Decimal(doubleValue)
        guard !decimalValue.isNaN else { return nil }
        self.decimalValue = decimalValue
    }

    /// Decodes a representable finite base-10 number.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Decimal.self)
        guard !value.isNaN else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "JSON numbers must be finite Decimal values"
            )
        }
        self.decimalValue = value
    }

    /// Encodes the represented base-10 number.
    public func encode(to encoder: Encoder) throws {
        guard !decimalValue.isNaN else {
            throw EncodingError.invalidValue(
                decimalValue,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "JSON numbers must be finite Decimal values"
                )
            )
        }
        var container = encoder.singleValueContainer()
        try container.encode(decimalValue)
    }
}

extension JSONNumber: ExpressibleByIntegerLiteral {
    /// Creates a decimal number from an integer literal.
    public init(integerLiteral value: Int64) {
        self.decimalValue = Decimal(value)
    }
}

/// A recursive representation of any supported JSON value.
///
/// Use this type when an API object must retain structured fields that are not yet
/// modeled by a typed Swift API. Object keys are encoded exactly as supplied.
/// Numbers use `Int64`, `UInt64`, or Foundation `Decimal` semantics. Their lexical
/// spelling and precision beyond the decoder's representable `Decimal` behavior are
/// not preserved.
public enum JSONValue: Codable, Sendable, Equatable {
    /// The JSON `null` value.
    case null
    /// A JSON Boolean.
    case bool(Bool)
    /// A JSON string.
    case string(String)
    /// A signed integral JSON number.
    case integer(Int64)
    /// An unsigned integral JSON number.
    case unsignedInteger(UInt64)
    /// A base-10 JSON number not represented by an integral case.
    case number(JSONNumber)
    /// A JSON array.
    case array([JSONValue])
    /// A JSON object.
    case object([String: JSONValue])

    /// Decodes a supported structured JSON value using the decoder's numeric semantics.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        if let value = try Self.decodeIfType(Bool.self, from: container) {
            self = .bool(value)
            return
        }
        if let value = try? container.decode(Int64.self) {
            self = .integer(value)
            return
        }
        if let value = try? container.decode(UInt64.self) {
            self = .unsignedInteger(value)
            return
        }
        if let value = try Self.decodeIfType(JSONNumber.self, from: container) {
            self = .number(value)
            return
        }
        if let value = try Self.decodeIfType(String.self, from: container) {
            self = .string(value)
            return
        }
        if let value = try Self.decodeIfType([JSONValue].self, from: container) {
            self = .array(value)
            return
        }
        if let value = try Self.decodeIfType([String: JSONValue].self, from: container) {
            self = .object(value)
            return
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Value is not valid JSON"
        )
    }

    /// Encodes the represented JSON value.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .unsignedInteger(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }

    private static func decodeIfType<T: Decodable>(
        _ type: T.Type,
        from container: SingleValueDecodingContainer
    ) throws -> T? {
        do {
            return try container.decode(type)
        } catch DecodingError.typeMismatch {
            return nil
        } catch DecodingError.valueNotFound {
            return nil
        } catch {
            throw error
        }
    }
}

extension JSONValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension JSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int64) {
        self = .integer(value)
    }
}

extension JSONValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSONValue...) {
        self = .array(elements)
    }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
    /// Creates a JSON object, with the last value winning for duplicate keys.
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        var object: [String: JSONValue] = [:]
        for (key, value) in elements {
            object[key] = value
        }
        self = .object(object)
    }
}
