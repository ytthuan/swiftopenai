import Foundation

// MARK: - ResponseInputContentPart

/// A content part in a multimodal Responses API input message.
///
/// Used to compose messages that mix text and images. Each part encodes
/// with a flat `type`-discriminated JSON structure specific to the Responses API.
///
/// Usage:
/// ```swift
/// let parts: [ResponseInputContentPart] = [
///     .inputText("What's in this image?"),
///     .inputImage(url: "https://example.com/photo.jpg", detail: .high)
/// ]
/// ```
public enum ResponseInputContentPart: Codable, Sendable, Equatable {
    /// Text content part.
    case inputText(String)
    /// Image content part — provide either `url` (HTTP or base64 data URI) or `fileId`.
    case inputImage(url: String? = nil, fileId: String? = nil, detail: ImageDetail? = nil)

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageUrl
        case fileId
        case detail
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "input_text":
            let text = try container.decode(String.self, forKey: .text)
            self = .inputText(text)
        case "input_image":
            let url = try container.decodeIfPresent(String.self, forKey: .imageUrl)
            let fileId = try container.decodeIfPresent(String.self, forKey: .fileId)
            let detail = try container.decodeIfPresent(ImageDetail.self, forKey: .detail)
            self = .inputImage(url: url, fileId: fileId, detail: detail)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown ResponseInputContentPart type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .inputText(let text):
            try container.encode("input_text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .inputImage(let url, let fileId, let detail):
            try container.encode("input_image", forKey: .type)
            try container.encodeIfPresent(url, forKey: .imageUrl)
            try container.encodeIfPresent(fileId, forKey: .fileId)
            try container.encodeIfPresent(detail, forKey: .detail)
        }
    }
}

// MARK: - Data Convenience

extension ResponseInputContentPart {
    /// Creates an image input part from raw image data.
    ///
    /// Encodes the data as a base64 data URI automatically.
    ///
    /// Usage:
    /// ```swift
    /// let part: ResponseInputContentPart = .inputImage(data: pngData, mimeType: .png)
    /// ```
    ///
    /// - Parameters:
    ///   - data: The raw image data.
    ///   - mimeType: The MIME type of the image.
    ///   - detail: The detail level for image processing. Defaults to `nil`.
    /// - Returns: An `.inputImage` content part with a base64 data URI.
    public static func inputImage(data: Data, mimeType: ImageMediaType, detail: ImageDetail? = nil) -> Self {
        .inputImage(url: "data:\(mimeType.rawValue);base64,\(data.base64EncodedString())", detail: detail)
    }
}

// MARK: - ResponseInputContent

/// Content for a Responses API input message — either plain text or multimodal parts.
///
/// When encoded, `.text` produces a plain JSON string while `.parts` produces
/// an array of typed content part objects.
///
/// Usage:
/// ```swift
/// // Plain text
/// let content: ResponseInputContent = .text("Hello")
///
/// // Multimodal
/// let content: ResponseInputContent = .parts([
///     .inputText("Describe this image"),
///     .inputImage(url: "https://example.com/photo.jpg")
/// ])
/// ```
public enum ResponseInputContent: Codable, Sendable, Equatable {
    /// Plain text content.
    case text(String)
    /// An array of multimodal content parts.
    case parts([ResponseInputContentPart])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else {
            let parts = try container.decode([ResponseInputContentPart].self)
            self = .parts(parts)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let text):
            try container.encode(text)
        case .parts(let parts):
            try container.encode(parts)
        }
    }
}

// MARK: - ExpressibleByStringLiteral

extension ResponseInputContent: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .text(value)
    }
}

// MARK: - ExpressibleByArrayLiteral

extension ResponseInputContent: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: ResponseInputContentPart...) {
        self = .parts(elements)
    }
}
