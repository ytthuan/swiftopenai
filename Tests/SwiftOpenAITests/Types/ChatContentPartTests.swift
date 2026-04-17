import Testing
import Foundation
@testable import SwiftOpenAI

@Suite struct ChatContentPartTests {
    let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()
    let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - ImageDetail

    @Test func imageDetailAutoRoundTrip() throws {
        let data = try encoder.encode(ImageDetail.auto)
        let decoded = try decoder.decode(ImageDetail.self, from: data)
        #expect(decoded == .auto)
    }

    @Test func imageDetailLowRoundTrip() throws {
        let data = try encoder.encode(ImageDetail.low)
        let decoded = try decoder.decode(ImageDetail.self, from: data)
        #expect(decoded == .low)
    }

    @Test func imageDetailHighRoundTrip() throws {
        let data = try encoder.encode(ImageDetail.high)
        let decoded = try decoder.decode(ImageDetail.self, from: data)
        #expect(decoded == .high)
    }

    @Test func imageDetailOriginalRoundTrip() throws {
        let data = try encoder.encode(ImageDetail.original)
        let decoded = try decoder.decode(ImageDetail.self, from: data)
        #expect(decoded == .original)
    }

    @Test func imageDetailUnknownValueDecodesToOther() throws {
        let json = #""ultra_hd""#
        let decoded = try decoder.decode(ImageDetail.self, from: Data(json.utf8))
        #expect(decoded == .other("ultra_hd"))
    }

    @Test func imageDetailOtherEncodesRawValue() throws {
        let detail = ImageDetail.other("custom_detail")
        let data = try encoder.encode(detail)
        let str = String(data: data, encoding: .utf8)!
        #expect(str == #""custom_detail""#)
    }

    // MARK: - ChatCompletionImageURL

    @Test func imageURLWithDetail() throws {
        let imageURL = ChatCompletionImageURL(url: "https://example.com/img.png", detail: .high)
        let data = try encoder.encode(imageURL)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["url"] as? String == "https://example.com/img.png")
        #expect(json["detail"] as? String == "high")
    }

    @Test func imageURLWithoutDetail() throws {
        let imageURL = ChatCompletionImageURL(url: "https://example.com/img.png")
        let data = try encoder.encode(imageURL)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["url"] as? String == "https://example.com/img.png")
        #expect(json["detail"] == nil)
    }

    @Test func imageURLBase64DataURI() throws {
        let dataURI = "data:image/png;base64,iVBORw0KGgo="
        let imageURL = ChatCompletionImageURL(url: dataURI, detail: .low)
        let data = try encoder.encode(imageURL)
        let decoded = try decoder.decode(ChatCompletionImageURL.self, from: data)
        #expect(decoded.url == dataURI)
        #expect(decoded.detail == .low)
    }

    // MARK: - ChatCompletionContentPart Encoding

    @Test func textPartEncoding() throws {
        let part = ChatCompletionContentPart.text("hello")
        let data = try encoder.encode(part)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["type"] as? String == "text")
        #expect(json["text"] as? String == "hello")
    }

    @Test func textPartDecoding() throws {
        let json = #"{"type":"text","text":"hello"}"#
        let part = try decoder.decode(ChatCompletionContentPart.self, from: Data(json.utf8))
        #expect(part == .text("hello"))
    }

    @Test func textPartRoundTrip() throws {
        let original = ChatCompletionContentPart.text("hello world")
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ChatCompletionContentPart.self, from: data)
        #expect(decoded == original)
    }

    @Test func imageURLPartEncoding() throws {
        let part = ChatCompletionContentPart.imageURL(
            ChatCompletionImageURL(url: "https://example.com/img.png", detail: .auto)
        )
        let data = try encoder.encode(part)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["type"] as? String == "image_url")
        let nested = json["image_url"] as? [String: Any]
        #expect(nested?["url"] as? String == "https://example.com/img.png")
        #expect(nested?["detail"] as? String == "auto")
    }

    @Test func imageURLPartDecoding() throws {
        let json = #"{"type":"image_url","image_url":{"url":"https://example.com/img.png","detail":"high"}}"#
        let part = try decoder.decode(ChatCompletionContentPart.self, from: Data(json.utf8))
        if case .imageURL(let imageURL) = part {
            #expect(imageURL.url == "https://example.com/img.png")
            #expect(imageURL.detail == .high)
        } else {
            #expect(Bool(false), "Expected .imageURL case")
        }
    }

    @Test func imageURLPartRoundTrip() throws {
        let original = ChatCompletionContentPart.imageURL(
            ChatCompletionImageURL(url: "https://example.com/photo.jpg", detail: .low)
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ChatCompletionContentPart.self, from: data)
        #expect(decoded == original)
    }

    @Test func unknownTypeDecodesToOther() throws {
        let json = #"{"type":"video","url":"https://example.com/vid.mp4"}"#
        let part = try decoder.decode(ChatCompletionContentPart.self, from: Data(json.utf8))
        #expect(part == .other(type: "video"))
    }

    @Test func otherPartEncodesTypeOnly() throws {
        let part = ChatCompletionContentPart.other(type: "input_audio")
        let data = try encoder.encode(part)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["type"] as? String == "input_audio")
    }

    @Test func userMessageWithUnknownContentPartPreservesKnownParts() throws {
        let json = """
        {"role":"user","content":[
          {"type":"text","text":"Look at this"},
          {"type":"input_audio","input_audio":{"data":"abc","format":"wav"}}
        ]}
        """
        let msg = try decoder.decode(ChatCompletionMessage.self, from: Data(json.utf8))
        if case .userParts(let parts) = msg {
            #expect(parts.count == 2)
            #expect(parts[0] == .text("Look at this"))
            #expect(parts[1] == .other(type: "input_audio"))
        } else {
            Issue.record("Expected .userParts, got \(msg)")
        }
    }

    // MARK: - ChatCompletionMessage multimodal

    @Test func userStringEncodesAsPlainString() throws {
        let msg = ChatCompletionMessage.user("just text")
        let data = try encoder.encode(msg)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["role"] as? String == "user")
        #expect(json["content"] as? String == "just text")
    }

    @Test func userPartsEncodesAsArray() throws {
        let msg = ChatCompletionMessage.userParts([
            .text("What's in this image?"),
            .imageURL(ChatCompletionImageURL(url: "https://example.com/img.png")),
        ])
        let data = try encoder.encode(msg)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["role"] as? String == "user")
        let content = json["content"] as? [[String: Any]]
        #expect(content?.count == 2)
        #expect(content?[0]["type"] as? String == "text")
        #expect(content?[1]["type"] as? String == "image_url")
    }

    @Test func userStringDecodesFromPlainString() throws {
        let json = #"{"role":"user","content":"hello"}"#
        let msg = try decoder.decode(ChatCompletionMessage.self, from: Data(json.utf8))
        if case .user(let text) = msg {
            #expect(text == "hello")
        } else {
            #expect(Bool(false), "Expected .user case")
        }
    }

    @Test func userPartsDecodesFromArray() throws {
        let json = #"""
        {
          "role": "user",
          "content": [
            {"type": "text", "text": "Describe this"},
            {"type": "image_url", "image_url": {"url": "https://example.com/img.png", "detail": "low"}}
          ]
        }
        """#
        let msg = try decoder.decode(ChatCompletionMessage.self, from: Data(json.utf8))
        if case .userParts(let parts) = msg {
            #expect(parts.count == 2)
            #expect(parts[0] == .text("Describe this"))
            if case .imageURL(let imageURL) = parts[1] {
                #expect(imageURL.url == "https://example.com/img.png")
                #expect(imageURL.detail == .low)
            } else {
                #expect(Bool(false), "Expected .imageURL for second part")
            }
        } else {
            #expect(Bool(false), "Expected .userParts case, got \(msg)")
        }
    }

    @Test func userPartsRoundTrip() throws {
        let original = ChatCompletionMessage.userParts([
            .text("What's in this image?"),
            .imageURL(ChatCompletionImageURL(url: "https://example.com/img.png", detail: .high)),
        ])
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ChatCompletionMessage.self, from: data)
        if case .userParts(let parts) = decoded {
            #expect(parts.count == 2)
            #expect(parts[0] == .text("What's in this image?"))
            if case .imageURL(let url) = parts[1] {
                #expect(url.url == "https://example.com/img.png")
                #expect(url.detail == .high)
            } else {
                #expect(Bool(false), "Expected .imageURL")
            }
        } else {
            #expect(Bool(false), "Expected .userParts after round-trip")
        }
    }

    @Test func userConvenienceWithImageURL() throws {
        let msg = ChatCompletionMessage.user(
            text: "Describe this photo",
            imageURL: "https://example.com/photo.jpg",
            detail: .high
        )
        let data = try encoder.encode(msg)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["role"] as? String == "user")
        let content = json["content"] as? [[String: Any]]
        #expect(content?.count == 2)
        #expect(content?[0]["type"] as? String == "text")
        #expect(content?[0]["text"] as? String == "Describe this photo")
        #expect(content?[1]["type"] as? String == "image_url")
        let nested = content?[1]["image_url"] as? [String: Any]
        #expect(nested?["url"] as? String == "https://example.com/photo.jpg")
        #expect(nested?["detail"] as? String == "high")
    }

    @Test func backwardCompatUserStringUnchanged() throws {
        let msg = ChatCompletionMessage.user("just text")
        let data = try encoder.encode(msg)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["role"] as? String == "user")
        #expect(json["content"] as? String == "just text")
        // Verify content is NOT an array
        #expect(json["content"] is String)
    }

    // MARK: - ImageMediaType

    @Test func imageMediaTypePNGRawValue() {
        #expect(ImageMediaType.png.rawValue == "image/png")
    }

    @Test func imageMediaTypeJPEGRawValue() {
        #expect(ImageMediaType.jpeg.rawValue == "image/jpeg")
    }

    @Test func imageMediaTypeGIFRawValue() {
        #expect(ImageMediaType.gif.rawValue == "image/gif")
    }

    @Test func imageMediaTypeWebPRawValue() {
        #expect(ImageMediaType.webp.rawValue == "image/webp")
    }

    // MARK: - Data-based convenience

    @Test func imageURLFromDataConstructsDataURI() throws {
        let data = Data([0x89, 0x50, 0x4E, 0x47])  // PNG magic bytes (fake small data)
        let imageURL = ChatCompletionImageURL(data: data, mimeType: .png, detail: .high)
        let expectedBase64 = data.base64EncodedString()
        #expect(imageURL.url == "data:image/png;base64,\(expectedBase64)")
        #expect(imageURL.detail == .high)
    }

    @Test func imageURLFromDataWithoutDetail() throws {
        let data = Data([0xFF, 0xD8, 0xFF])  // JPEG magic bytes
        let imageURL = ChatCompletionImageURL(data: data, mimeType: .jpeg)
        #expect(imageURL.url.hasPrefix("data:image/jpeg;base64,"))
        #expect(imageURL.detail == nil)
    }

    @Test func contentPartImageDataFactory() throws {
        let data = Data([0x47, 0x49, 0x46])  // GIF magic
        let part = ChatCompletionContentPart.imageData(data, mimeType: .gif, detail: .low)
        // Should encode as image_url type
        let encoded = try encoder.encode(part)
        let json = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        #expect(json["type"] as? String == "image_url")
        let imageUrlObj = json["image_url"] as! [String: Any]
        #expect((imageUrlObj["url"] as? String)?.hasPrefix("data:image/gif;base64,") == true)
        #expect(imageUrlObj["detail"] as? String == "low")
    }

    @Test func messageUserWithImageData() throws {
        let data = Data([0x52, 0x49, 0x46, 0x46])  // WebP magic
        let msg = ChatCompletionMessage.user(text: "describe", imageData: data, mimeType: .webp, detail: .auto)
        let encoded = try encoder.encode(msg)
        let json = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        #expect(json["role"] as? String == "user")
        let content = json["content"] as! [[String: Any]]
        #expect(content.count == 2)
        #expect(content[0]["type"] as? String == "text")
        #expect(content[0]["text"] as? String == "describe")
        #expect(content[1]["type"] as? String == "image_url")
    }
}
