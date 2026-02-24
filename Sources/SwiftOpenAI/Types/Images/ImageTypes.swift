import Foundation

/// Response from image generation, edit, and variation endpoints.
public struct ImagesResponse: Codable, Sendable {
    /// Unix timestamp when the images were created.
    public let created: Int
    /// The list of generated images.
    public let data: [ImageData]
}

/// A single image result.
public struct ImageData: Codable, Sendable {
    /// The URL of the generated image (when response format is "url").
    public let url: String?
    /// The base64-encoded JSON of the generated image (when response format is "b64_json").
    public let b64Json: String?
    /// The revised prompt used to generate the image (DALL·E 3 only).
    public let revisedPrompt: String?
}
