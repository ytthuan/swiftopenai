import Foundation

// MARK: - ImageMediaType

/// MIME type for image content parts.
///
/// Used with `Data`-based convenience initializers to construct
/// base64-encoded data URIs automatically.
public enum ImageMediaType: String, Sendable {
    /// PNG image (`image/png`)
    case png = "image/png"
    /// JPEG image (`image/jpeg`)
    case jpeg = "image/jpeg"
    /// GIF image (`image/gif`)
    case gif = "image/gif"
    /// WebP image (`image/webp`)
    case webp = "image/webp"
}

// MARK: - ImageDetail

/// Detail level for image inputs in Chat Completions.
///
/// Controls the resolution at which the model processes the image.
/// - `auto`: Let the model decide the appropriate detail level.
/// - `low`: Use a lower-resolution version of the image (faster, fewer tokens).
/// - `high`: Use a higher-resolution version of the image (more detail, more tokens).
/// - `original`: Use the original resolution of the image.
/// - `other`: Forward-compatible case for unknown detail levels.
public enum ImageDetail: Codable, Sendable, Equatable {
    case auto
    case low
    case high
    case original
    case other(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "auto": self = .auto
        case "low": self = .low
        case "high": self = .high
        case "original": self = .original
        default: self = .other(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .auto: try container.encode("auto")
        case .low: try container.encode("low")
        case .high: try container.encode("high")
        case .original: try container.encode("original")
        case .other(let value): try container.encode(value)
        }
    }
}

// MARK: - ChatCompletionImageURL

/// Image URL for Chat Completions content parts.
///
/// Supports both HTTP/HTTPS URLs and inline base64-encoded data URIs
/// (e.g., `data:image/png;base64,...`).
public struct ChatCompletionImageURL: Codable, Sendable, Equatable {
    /// The URL of the image. Can be an HTTP URL or a `data:image/...;base64,...` data URI.
    public let url: String

    /// The detail level at which the model should process the image.
    /// If `nil`, the model uses its default behavior.
    public let detail: ImageDetail?

    /// Creates an image URL content part.
    /// - Parameters:
    ///   - url: The URL of the image (HTTP URL or base64 data URI).
    ///   - detail: The detail level for image processing. Defaults to `nil`.
    public init(url: String, detail: ImageDetail? = nil) {
        self.url = url
        self.detail = detail
    }
}

extension ChatCompletionImageURL {
    /// Creates an image URL from raw image data, encoding it as a base64 data URI.
    ///
    /// Usage:
    /// ```swift
    /// let imageData = try Data(contentsOf: imageFileURL)
    /// let imageURL = ChatCompletionImageURL(data: imageData, mimeType: .png, detail: .high)
    /// ```
    ///
    /// - Parameters:
    ///   - data: The raw image data.
    ///   - mimeType: The MIME type of the image.
    ///   - detail: The detail level for image processing. Defaults to `nil`.
    public init(data: Data, mimeType: ImageMediaType, detail: ImageDetail? = nil) {
        self.init(
            url: "data:\(mimeType.rawValue);base64,\(data.base64EncodedString())",
            detail: detail
        )
    }
}

// MARK: - ChatCompletionContentPart

/// A content part in a multimodal Chat Completions message.
///
/// Used to compose messages that include both text and images.
///
/// Usage:
/// ```swift
/// let parts: [ChatCompletionContentPart] = [
///     .text("What's in this image?"),
///     .imageURL(ChatCompletionImageURL(url: "https://example.com/image.png", detail: .high))
/// ]
/// ```
///
/// Wire format (type-discriminated JSON):
/// - `.text("hello")` → `{"type": "text", "text": "hello"}`
/// - `.imageURL(...)` → `{"type": "image_url", "image_url": {"url": "...", "detail": "high"}}`
public enum ChatCompletionContentPart: Codable, Sendable, Equatable {
    /// A text content part.
    case text(String)

    /// An image URL content part.
    case imageURL(ChatCompletionImageURL)

    /// A forward-compatible case for unknown content part types.
    ///
    /// When the API introduces new part types (e.g. `"input_audio"`), they decode
    /// into this case instead of throwing, preventing silent data loss in arrays.
    case other(type: String)

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageUrl
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "image_url":
            let imageUrl = try container.decode(ChatCompletionImageURL.self, forKey: .imageUrl)
            self = .imageURL(imageUrl)
        default:
            self = .other(type: type)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .imageURL(let imageUrl):
            try container.encode("image_url", forKey: .type)
            try container.encode(imageUrl, forKey: .imageUrl)
        case .other(let type):
            try container.encode(type, forKey: .type)
        }
    }
}

// MARK: - Data Convenience

extension ChatCompletionContentPart {
    /// Creates an image content part from raw image data.
    ///
    /// Encodes the data as a base64 data URI automatically.
    ///
    /// Usage:
    /// ```swift
    /// let part: ChatCompletionContentPart = .imageData(pngData, mimeType: .png)
    /// ```
    ///
    /// - Parameters:
    ///   - data: The raw image data.
    ///   - mimeType: The MIME type of the image.
    ///   - detail: The detail level for image processing. Defaults to `nil`.
    /// - Returns: An `.imageURL` content part with a base64 data URI.
    public static func imageData(_ data: Data, mimeType: ImageMediaType, detail: ImageDetail? = nil) -> Self {
        .imageURL(ChatCompletionImageURL(data: data, mimeType: mimeType, detail: detail))
    }
}
