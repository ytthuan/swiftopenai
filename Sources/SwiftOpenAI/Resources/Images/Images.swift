import Foundation

/// Access the OpenAI Images API.
///
/// Generate, edit, and create variations of images.
///
/// Usage:
/// ```swift
/// let response = try await client.images.generate(
///     prompt: "A cute cat",
///     model: "dall-e-3"
/// )
/// ```
public struct Images: Sendable {

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    // MARK: - Generate

    /// Generates images from a text prompt.
    ///
    /// - Parameters:
    ///   - prompt: A text description of the desired image(s).
    ///   - model: The model to use ("dall-e-2" or "dall-e-3").
    ///   - n: Number of images to generate (1–10).
    ///   - size: Size of the generated images.
    ///   - quality: Quality level ("standard" or "hd").
    ///   - style: Style ("vivid" or "natural").
    ///   - responseFormat: Response format ("url" or "b64_json").
    ///   - user: A unique identifier for the end-user.
    /// - Returns: An ``ImagesResponse`` containing the generated images.
    public func generate(
        prompt: String,
        model: String? = nil,
        n: Int? = nil,
        size: String? = nil,
        quality: String? = nil,
        style: String? = nil,
        responseFormat: String? = nil,
        user: String? = nil
    ) async throws -> ImagesResponse {
        let body = ImageGenerateParams(
            prompt: prompt,
            model: model,
            n: n,
            size: size,
            quality: quality,
            style: style,
            responseFormat: responseFormat,
            user: user
        )
        return try await client.post(path: "images/generations", body: body)
    }

    // MARK: - Edit

    /// Creates an edited or extended image.
    ///
    /// - Parameters:
    ///   - image: The image to edit (PNG, < 4 MB, square).
    ///   - prompt: A text description of the desired edits.
    ///   - mask: An additional image whose transparent areas indicate where to edit.
    ///   - model: The model to use.
    ///   - n: Number of images to generate.
    ///   - size: Size of the generated images.
    ///   - responseFormat: Response format.
    ///   - user: End-user identifier.
    /// - Returns: An ``ImagesResponse`` containing the edited images.
    public func edit(
        image: Data,
        prompt: String,
        mask: Data? = nil,
        model: String? = nil,
        n: Int? = nil,
        size: String? = nil,
        responseFormat: String? = nil,
        user: String? = nil
    ) async throws -> ImagesResponse {
        var formData = MultipartFormData()
        formData.addFile(name: "image", filename: "image.png", mimeType: "image/png", data: image)
        formData.addField(name: "prompt", value: prompt)
        if let mask {
            formData.addFile(name: "mask", filename: "mask.png", mimeType: "image/png", data: mask)
        }
        if let model { formData.addField(name: "model", value: model) }
        if let n { formData.addField(name: "n", value: String(n)) }
        if let size { formData.addField(name: "size", value: size) }
        if let responseFormat { formData.addField(name: "response_format", value: responseFormat) }
        if let user { formData.addField(name: "user", value: user) }
        return try await client.postMultipart(path: "images/edits", formData: formData)
    }

    // MARK: - Variations

    /// Creates a variation of a given image.
    ///
    /// - Parameters:
    ///   - image: The image to create a variation of (PNG, < 4 MB, square).
    ///   - model: The model to use.
    ///   - n: Number of images to generate.
    ///   - size: Size of the generated images.
    ///   - responseFormat: Response format.
    ///   - user: End-user identifier.
    /// - Returns: An ``ImagesResponse`` containing the image variations.
    public func createVariation(
        image: Data,
        model: String? = nil,
        n: Int? = nil,
        size: String? = nil,
        responseFormat: String? = nil,
        user: String? = nil
    ) async throws -> ImagesResponse {
        var formData = MultipartFormData()
        formData.addFile(name: "image", filename: "image.png", mimeType: "image/png", data: image)
        if let model { formData.addField(name: "model", value: model) }
        if let n { formData.addField(name: "n", value: String(n)) }
        if let size { formData.addField(name: "size", value: size) }
        if let responseFormat { formData.addField(name: "response_format", value: responseFormat) }
        if let user { formData.addField(name: "user", value: user) }
        return try await client.postMultipart(path: "images/variations", formData: formData)
    }
}

// MARK: - Request Parameters

/// Parameters for image generation.
struct ImageGenerateParams: Encodable, Sendable {
    let prompt: String
    let model: String?
    let n: Int?
    let size: String?
    let quality: String?
    let style: String?
    let responseFormat: String?
    let user: String?
}
