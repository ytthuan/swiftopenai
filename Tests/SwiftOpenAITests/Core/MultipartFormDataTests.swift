import Testing
import Foundation
@testable import SwiftOpenAI

@Suite struct MultipartFormDataTests {

    @Test func encodesTextField() {
        var form = MultipartFormData(boundary: "test-boundary")
        form.addField(name: "model", value: "whisper-1")
        let data = form.encode()
        let body = String(data: data, encoding: .utf8)!

        #expect(body.contains("Content-Disposition: form-data; name=\"model\""))
        #expect(body.contains("whisper-1"))
        #expect(body.contains("--test-boundary"))
        #expect(body.contains("--test-boundary--"))
    }

    @Test func encodesFileField() {
        var form = MultipartFormData(boundary: "test-boundary")
        let fileData = Data("fake audio content".utf8)
        form.addFile(name: "file", filename: "audio.mp3", mimeType: "audio/mpeg", data: fileData)
        let data = form.encode()
        let body = String(data: data, encoding: .utf8)!

        #expect(body.contains("Content-Disposition: form-data; name=\"file\"; filename=\"audio.mp3\""))
        #expect(body.contains("Content-Type: audio/mpeg"))
        #expect(body.contains("fake audio content"))
    }

    @Test func encodesMultipleFields() {
        var form = MultipartFormData(boundary: "test-boundary")
        form.addField(name: "model", value: "whisper-1")
        form.addField(name: "language", value: "en")
        let fileData = Data("audio bytes".utf8)
        form.addFile(name: "file", filename: "test.mp3", mimeType: "audio/mpeg", data: fileData)
        let data = form.encode()
        let body = String(data: data, encoding: .utf8)!

        #expect(body.contains("name=\"model\""))
        #expect(body.contains("whisper-1"))
        #expect(body.contains("name=\"language\""))
        #expect(body.contains("en"))
        #expect(body.contains("name=\"file\"; filename=\"test.mp3\""))
        #expect(body.contains("audio bytes"))
    }

    @Test func sanitizesFilenameWithQuotes() {
        var form = MultipartFormData(boundary: "test-boundary")
        let fileData = Data("data".utf8)
        form.addFile(name: "file", filename: "test\"evil.txt", mimeType: "text/plain", data: fileData)
        let data = form.encode()
        let body = String(data: data, encoding: .utf8)!

        #expect(body.contains("filename=\"test\\\"evil.txt\""))
        #expect(!body.contains("filename=\"test\"evil.txt\""))
    }

    @Test func sanitizesFilenameWithCRLF() {
        var form = MultipartFormData(boundary: "test-boundary")
        let fileData = Data("data".utf8)
        form.addFile(name: "file", filename: "test\r\nevil.txt", mimeType: "text/plain", data: fileData)
        let data = form.encode()
        let body = String(data: data, encoding: .utf8)!

        #expect(body.contains("filename=\"testevil.txt\""))
        #expect(!body.contains("test\r\nevil.txt"))
    }

    @Test func contentTypeIncludesBoundary() {
        let form = MultipartFormData(boundary: "test-boundary")
        #expect(form.contentType == "multipart/form-data; boundary=test-boundary")
    }

    @Test func sanitizesMimeTypeWithCRLF() {
        var form = MultipartFormData(boundary: "test-boundary")
        let fileData = Data("data".utf8)
        form.addFile(name: "file", filename: "test.txt", mimeType: "text/plain\r\nX-Evil: injected", data: fileData)
        let data = form.encode()
        let body = String(data: data, encoding: .utf8)!

        #expect(body.contains("Content-Type: text/plainX-Evil: injected"))
        #expect(!body.contains("Content-Type: text/plain\r\nX-Evil"))
    }
}
