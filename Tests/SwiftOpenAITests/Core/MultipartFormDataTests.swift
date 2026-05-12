import Testing
import Foundation
@testable import SwiftOpenAI

@Suite struct MultipartFormDataTests {

    @Test func encodesTextField() throws {
        var form = MultipartFormData(boundary: "test-boundary")
        form.addField(name: "model", value: "whisper-1")
        let data = try form.encode()
        let body = String(data: data, encoding: .utf8)!

        #expect(body.contains("Content-Disposition: form-data; name=\"model\""))
        #expect(body.contains("whisper-1"))
        #expect(body.contains("--test-boundary"))
        #expect(body.contains("--test-boundary--"))
    }

    @Test func encodesFileField() throws {
        var form = MultipartFormData(boundary: "test-boundary")
        let fileData = Data("fake audio content".utf8)
        form.addFile(name: "file", filename: "audio.mp3", mimeType: "audio/mpeg", data: fileData)
        let data = try form.encode()
        let body = String(data: data, encoding: .utf8)!

        #expect(body.contains("Content-Disposition: form-data; name=\"file\"; filename=\"audio.mp3\""))
        #expect(body.contains("Content-Type: audio/mpeg"))
        #expect(body.contains("fake audio content"))
    }

    @Test func encodesMultipleFields() throws {
        var form = MultipartFormData(boundary: "test-boundary")
        form.addField(name: "model", value: "whisper-1")
        form.addField(name: "language", value: "en")
        let fileData = Data("audio bytes".utf8)
        form.addFile(name: "file", filename: "test.mp3", mimeType: "audio/mpeg", data: fileData)
        let data = try form.encode()
        let body = String(data: data, encoding: .utf8)!

        #expect(body.contains("name=\"model\""))
        #expect(body.contains("whisper-1"))
        #expect(body.contains("name=\"language\""))
        #expect(body.contains("en"))
        #expect(body.contains("name=\"file\"; filename=\"test.mp3\""))
        #expect(body.contains("audio bytes"))
    }

    @Test func sanitizesFilenameWithQuotes() throws {
        var form = MultipartFormData(boundary: "test-boundary")
        let fileData = Data("data".utf8)
        form.addFile(name: "file", filename: "test\"evil.txt", mimeType: "text/plain", data: fileData)
        let data = try form.encode()
        let body = String(data: data, encoding: .utf8)!

        #expect(body.contains("filename=\"test\\\"evil.txt\""))
        #expect(!body.contains("filename=\"test\"evil.txt\""))
    }

    @Test func sanitizesFilenameWithCRLF() throws {
        var form = MultipartFormData(boundary: "test-boundary")
        let fileData = Data("data".utf8)
        form.addFile(name: "file", filename: "test\r\nevil.txt", mimeType: "text/plain", data: fileData)
        let data = try form.encode()
        let body = String(data: data, encoding: .utf8)!

        #expect(body.contains("filename=\"testevil.txt\""))
        #expect(!body.contains("test\r\nevil.txt"))
    }

    @Test func contentTypeIncludesBoundary() {
        let form = MultipartFormData(boundary: "test-boundary")
        #expect(form.contentType == "multipart/form-data; boundary=test-boundary")
    }

    @Test func sanitizesMimeTypeWithCRLF() throws {
        var form = MultipartFormData(boundary: "test-boundary")
        let fileData = Data("data".utf8)
        form.addFile(name: "file", filename: "test.txt", mimeType: "text/plain\r\nX-Evil: injected", data: fileData)
        let data = try form.encode()
        let body = String(data: data, encoding: .utf8)!

        #expect(body.contains("Content-Type: text/plainX-Evil: injected"))
        #expect(!body.contains("Content-Type: text/plain\r\nX-Evil"))
    }

    // MARK: - v0.10.1 Security Patch: Size-Limit Enforcement

    @Test func oversizedPartIsRejectedPreAllocation() throws {
        var form = MultipartFormData(boundary: "test-boundary")
        let oversizedData = Data(repeating: 0x41, count: 32)
        form.addFile(name: "file", filename: "big.bin", mimeType: "application/octet-stream", data: oversizedData)

        do {
            _ = try form.encode(maxPartSize: 16)
            Issue.record("Expected bufferOverflow to be thrown")
        } catch let error as OpenAIError {
            guard case .bufferOverflow(let message) = error else {
                Issue.record("Expected bufferOverflow, got \(error)")
                return
            }
            #expect(message.contains("16"))
            #expect(!message.contains("big.bin"))
        }
    }

    @Test func oversizedBodyIsRejectedPreAllocation() throws {
        var form = MultipartFormData(boundary: "b")
        for i in 0..<3 {
            form.addFile(
                name: "f\(i)", filename: "f\(i).bin",
                mimeType: "application/octet-stream",
                data: Data(repeating: 0x42, count: 30)
            )
        }

        do {
            _ = try form.encode(maxPartSize: .max, maxBodySize: 64)
            Issue.record("Expected bufferOverflow to be thrown")
        } catch let error as OpenAIError {
            guard case .bufferOverflow(let message) = error else {
                Issue.record("Expected bufferOverflow, got \(error)")
                return
            }
            #expect(message.contains("64"))
            #expect(!message.contains("f0"))
            #expect(!message.contains("f1"))
            #expect(!message.contains("f0.bin"))
        }
    }

    @Test func customLimitsAreHonoredAtBoundary() throws {
        // Part exactly at limit — should succeed
        var formAtLimit = MultipartFormData(boundary: "b")
        formAtLimit.addField(name: "x", value: String(repeating: "a", count: 16))
        let _ = try formAtLimit.encode(maxPartSize: 16)

        // Part one byte over limit — should throw
        var formOverLimit = MultipartFormData(boundary: "b")
        formOverLimit.addField(name: "x", value: String(repeating: "a", count: 17))
        #expect(throws: OpenAIError.self) {
            try formOverLimit.encode(maxPartSize: 16)
        }
    }

    @Test func defaultLimitsMatchDocumentedValues() {
        let config = Configuration(apiKey: "sk-test")
        #expect(config.maxMultipartPartSize == 512 * 1024 * 1024)
        #expect(config.maxMultipartBodySize == 1024 * 1024 * 1024)
    }

    @Test func optOutWithIntMaxAcceptsParts() throws {
        var form = MultipartFormData(boundary: "test-boundary")
        form.addField(name: "model", value: "whisper-1")
        form.addFile(name: "file", filename: "test.mp3", mimeType: "audio/mpeg", data: Data("audio".utf8))

        // Should succeed with .max limits
        let dataWithMax = try form.encode(maxPartSize: .max, maxBodySize: .max)
        // Wire output must be identical to default encode
        let dataDefault = try form.encode()
        #expect(dataWithMax == dataDefault)
    }

    @Test func existingWireOutputPreservedAfterRefactor() throws {
        var form = MultipartFormData(boundary: "test-boundary")
        form.addField(name: "model", value: "whisper-1")
        let data = try form.encode()
        let body = String(data: data, encoding: .utf8)!

        // Verify exact wire format structure (regression for Data(capacity:) switch)
        #expect(body.hasPrefix("--test-boundary\r\n"))
        #expect(body.hasSuffix("--test-boundary--\r\n"))
        #expect(body.contains("Content-Disposition: form-data; name=\"model\"\r\n\r\nwhisper-1\r\n"))
    }

    @Test func longFilenameDoesNotUnderestimateBodySize() throws {
        var form = MultipartFormData(boundary: "test-boundary")
        let longName = String(repeating: "a", count: 80)
        let longFilename = String(repeating: "b", count: 80)
        let longMimeType = "application/octet-stream-x-vendor-extended-test"  // ~46 chars
        let payload = Data(repeating: 0xAB, count: 1000)
        form.addFile(name: longName, filename: longFilename, mimeType: longMimeType, data: payload)

        // Encode with default limits — should succeed
        let body = try form.encode()

        // Now encode with maxBodySize = body.count - 1 — must reject
        // (proves estimate is exact, not under)
        var form2 = MultipartFormData(boundary: "test-boundary")
        form2.addFile(name: longName, filename: longFilename, mimeType: longMimeType, data: payload)

        do {
            _ = try form2.encode(maxBodySize: body.count - 1)
            Issue.record("Expected bufferOverflow for maxBodySize one byte under exact size, but encode() succeeded")
        } catch let error as OpenAIError {
            guard case .bufferOverflow = error else {
                Issue.record("Expected bufferOverflow, got: \(error)")
                return
            }
            // Pass — exact size accounting is enforced
        }

        // And with maxBodySize = body.count exactly — must succeed (boundary)
        var form3 = MultipartFormData(boundary: "test-boundary")
        form3.addFile(name: longName, filename: longFilename, mimeType: longMimeType, data: payload)
        let body3 = try form3.encode(maxBodySize: body.count)
        #expect(body3.count == body.count)
    }

    @Test func staticErrorMessageDoesNotLeakCallerData() {
        var form = MultipartFormData(boundary: "test-boundary")
        let sensitiveFilename = "secret-payroll-2026-Q1.csv"
        let sensitiveFieldName = "Authorization-Token-Sample"
        form.addFile(
            name: sensitiveFieldName, filename: sensitiveFilename,
            mimeType: "text/csv", data: Data(repeating: 0x43, count: 32)
        )

        do {
            _ = try form.encode(maxPartSize: 16)
            Issue.record("Expected bufferOverflow to be thrown")
        } catch let error as OpenAIError {
            guard case .bufferOverflow(let message) = error else {
                Issue.record("Expected bufferOverflow, got \(error)")
                return
            }
            #expect(message.contains("16"))
            #expect(!message.contains(sensitiveFilename))
            #expect(!message.contains(sensitiveFieldName))
            #expect(!message.contains("payroll"))
            #expect(!message.contains("Authorization"))
        } catch {
            Issue.record("Expected OpenAIError, got \(error)")
        }
    }
}
