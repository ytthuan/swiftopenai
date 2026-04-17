import Testing
import Foundation
@testable import SwiftOpenAI

@Suite struct ResponseInputContentPartTests {
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

    // MARK: - ResponseInputContentPart — inputText

    @Test func inputTextEncoding() throws {
        let part = ResponseInputContentPart.inputText("hello")
        let data = try encoder.encode(part)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["type"] as? String == "input_text")
        #expect(json["text"] as? String == "hello")
    }

    @Test func inputTextDecoding() throws {
        let json = #"{"type":"input_text","text":"hello"}"#
        let part = try decoder.decode(ResponseInputContentPart.self, from: Data(json.utf8))
        #expect(part == .inputText("hello"))
    }

    @Test func inputTextRoundTrip() throws {
        let original = ResponseInputContentPart.inputText("round trip text")
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ResponseInputContentPart.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - ResponseInputContentPart — inputImage

    @Test func inputImageWithURLEncoding() throws {
        let part = ResponseInputContentPart.inputImage(
            url: "https://example.com/photo.jpg", detail: .high
        )
        let data = try encoder.encode(part)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["type"] as? String == "input_image")
        #expect(json["image_url"] as? String == "https://example.com/photo.jpg")
        #expect(json["detail"] as? String == "high")
        #expect(json["file_id"] == nil)
    }

    @Test func inputImageWithFileIdEncoding() throws {
        let part = ResponseInputContentPart.inputImage(fileId: "file-abc123", detail: .low)
        let data = try encoder.encode(part)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["type"] as? String == "input_image")
        #expect(json["file_id"] as? String == "file-abc123")
        #expect(json["detail"] as? String == "low")
        #expect(json["image_url"] == nil)
    }

    @Test func inputImageDecoding() throws {
        let json = #"{"type":"input_image","image_url":"https://example.com/img.png","detail":"auto"}"#
        let part = try decoder.decode(ResponseInputContentPart.self, from: Data(json.utf8))
        if case .inputImage(let url, let fileId, let detail) = part {
            #expect(url == "https://example.com/img.png")
            #expect(fileId == nil)
            #expect(detail == .auto)
        } else {
            #expect(Bool(false), "Expected .inputImage case")
        }
    }

    @Test func inputImageRoundTrip() throws {
        let original = ResponseInputContentPart.inputImage(
            url: "https://example.com/img.png", detail: .auto
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ResponseInputContentPart.self, from: data)
        #expect(decoded == original)
    }

    @Test func inputImageWithFileIdRoundTrip() throws {
        let original = ResponseInputContentPart.inputImage(fileId: "file-xyz", detail: .high)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ResponseInputContentPart.self, from: data)
        #expect(decoded == original)
    }

    @Test func unknownInputTypeThrowsOnDecode() throws {
        let json = #"{"type":"input_audio","data":"base64audio"}"#
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(ResponseInputContentPart.self, from: Data(json.utf8))
        }
    }

    // MARK: - ResponseInputContent

    @Test func textContentEncodesAsString() throws {
        let content = ResponseInputContent.text("plain text")
        let data = try encoder.encode(content)
        let str = String(data: data, encoding: .utf8)!
        #expect(str == #""plain text""#)
    }

    @Test func partsContentEncodesAsArray() throws {
        let content = ResponseInputContent.parts([
            .inputText("Describe"),
            .inputImage(url: "https://example.com/img.png"),
        ])
        let data = try encoder.encode(content)
        let arr = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        #expect(arr.count == 2)
        #expect(arr[0]["type"] as? String == "input_text")
        #expect(arr[1]["type"] as? String == "input_image")
    }

    @Test func textContentDecodesFromString() throws {
        let json = #""hello world""#
        let content = try decoder.decode(ResponseInputContent.self, from: Data(json.utf8))
        #expect(content == .text("hello world"))
    }

    @Test func partsContentDecodesFromArray() throws {
        let json = #"[{"type":"input_text","text":"hi"},{"type":"input_image","image_url":"https://example.com/img.png"}]"#
        let content = try decoder.decode(ResponseInputContent.self, from: Data(json.utf8))
        if case .parts(let parts) = content {
            #expect(parts.count == 2)
            #expect(parts[0] == .inputText("hi"))
        } else {
            #expect(Bool(false), "Expected .parts case")
        }
    }

    @Test func textContentRoundTrip() throws {
        let original = ResponseInputContent.text("round trip")
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ResponseInputContent.self, from: data)
        #expect(decoded == original)
    }

    @Test func partsContentRoundTrip() throws {
        let original = ResponseInputContent.parts([
            .inputText("What is this?"),
            .inputImage(url: "https://example.com/img.png", detail: .high),
        ])
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ResponseInputContent.self, from: data)
        #expect(decoded == original)
    }

    @Test func stringLiteralCreatesTextContent() throws {
        let content: ResponseInputContent = "literal text"
        #expect(content == .text("literal text"))
    }

    @Test func arrayLiteralCreatesPartsContent() throws {
        let content: ResponseInputContent = [
            .inputText("hello"),
            .inputImage(url: "https://example.com/img.png"),
        ]
        if case .parts(let parts) = content {
            #expect(parts.count == 2)
        } else {
            #expect(Bool(false), "Expected .parts case from array literal")
        }
    }

    // MARK: - ResponseInputMessage multimodal

    @Test func inputMessageWithStringContent() throws {
        let msg = ResponseInputMessage(role: "user", content: "Hello")
        let data = try encoder.encode(msg)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["type"] as? String == "message")
        #expect(json["role"] as? String == "user")
        #expect(json["content"] as? String == "Hello")
    }

    @Test func inputMessageWithPartsContent() throws {
        let msg = ResponseInputMessage(role: "user", content: .parts([
            .inputText("Describe this"),
            .inputImage(url: "https://example.com/photo.jpg", detail: .low),
        ]))
        let data = try encoder.encode(msg)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["type"] as? String == "message")
        #expect(json["role"] as? String == "user")
        let content = json["content"] as? [[String: Any]]
        #expect(content?.count == 2)
        #expect(content?[0]["type"] as? String == "input_text")
        #expect(content?[1]["type"] as? String == "input_image")
    }

    @Test func inputMessageConvenienceUserText() throws {
        let msg = ResponseInputMessage.user("Hello")
        let data = try encoder.encode(msg)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["role"] as? String == "user")
        #expect(json["content"] as? String == "Hello")
    }

    @Test func inputMessageConvenienceUserParts() throws {
        let msg = ResponseInputMessage.user(parts: [
            .inputText("What's this?"),
            .inputImage(url: "https://example.com/img.png"),
        ])
        let data = try encoder.encode(msg)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["role"] as? String == "user")
        let content = json["content"] as? [[String: Any]]
        #expect(content?.count == 2)
    }

    @Test func inputMessageConvenienceSystem() throws {
        let msg = ResponseInputMessage.system("You are helpful")
        let data = try encoder.encode(msg)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["role"] as? String == "system")
        #expect(json["content"] as? String == "You are helpful")
    }

    @Test func inputMessageConvenienceDeveloper() throws {
        let msg = ResponseInputMessage.developer("instructions")
        let data = try encoder.encode(msg)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["role"] as? String == "developer")
        #expect(json["content"] as? String == "instructions")
    }

    // MARK: - Data-based convenience

    @Test func inputImageFromDataConstructsDataURI() throws {
        let data = Data([0x89, 0x50, 0x4E, 0x47])
        let part = ResponseInputContentPart.inputImage(data: data, mimeType: .png, detail: .auto)
        let encoded = try encoder.encode(part)
        let json = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        #expect(json["type"] as? String == "input_image")
        #expect((json["image_url"] as? String)?.hasPrefix("data:image/png;base64,") == true)
        #expect(json["detail"] as? String == "auto")
    }
}
