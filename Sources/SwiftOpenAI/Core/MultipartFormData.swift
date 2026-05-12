import Foundation

/// Encodes multipart/form-data request bodies for file uploads.
struct MultipartFormData: Sendable {

    private let boundary: String
    private var parts: [Part] = []

    init(boundary: String = UUID().uuidString) {
        self.boundary = boundary
    }

    /// The Content-Type header value including boundary.
    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    // MARK: - Adding Parts

    /// Adds a text field.
    mutating func addField(name: String, value: String) {
        parts.append(.field(name: name, value: value))
    }

    /// Adds a file part.
    mutating func addFile(name: String, filename: String, mimeType: String, data: Data) {
        parts.append(.file(name: name, filename: filename, mimeType: mimeType, data: data))
    }

    // MARK: - Encoding

    /// Sanitizes a string for use in a Content-Disposition header value.
    /// Escapes quotes and strips CRLF characters to prevent header injection.
    private static func sanitizeHeaderValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// Encodes all parts into the final `Data` body.
    ///
    /// Enforces size caps **before** allocation: throws `OpenAIError.bufferOverflow`
    /// if any single part exceeds `maxPartSize` or if the total body would exceed `maxBodySize`.
    /// This protects server-side adopters from unbounded memory growth on attacker-controlled
    /// uploads (CWE-770).
    ///
    /// Builds directly into a single `Data` buffer (no intermediate `ContiguousArray`),
    /// reducing the encoder-side memory peak from ~3× to ~2× payload.
    ///
    /// - Parameters:
    ///   - maxPartSize: Maximum bytes for any single part. `.max` to disable.
    ///   - maxBodySize: Maximum bytes for the assembled body. `.max` to disable.
    /// - Throws: `OpenAIError.bufferOverflow` if any limit would be violated.
    func encode(maxPartSize: Int = .max, maxBodySize: Int = .max) throws -> Data {
        // 1. Per-part size enforcement (before any aggregation)
        for part in parts {
            let size: Int
            switch part {
            case .field(_, let value):
                size = value.utf8.count
            case .file(_, _, _, let data):
                size = data.count
            }
            if size > maxPartSize {
                throw OpenAIError.bufferOverflow(
                    message: "Multipart part exceeded \(maxPartSize) bytes"
                )
            }
        }

        // 2. Compute exact body size with checked arithmetic.
        //    This matches the build loop's output byte-for-byte, eliminating any
        //    under-estimate that could let oversized bodies slip past maxBodySize.
        let boundaryBytes = "--\(boundary)".utf8.count

        // Closing line: --<boundary>--\r\n
        var totalSize = boundaryBytes + 4

        for part in parts {
            let partSize: Int
            switch part {
            case .field(let name, let value):
                let safeName = Self.sanitizeHeaderValue(name)
                // --<boundary>\r\n
                // Content-Disposition: form-data; name="<safeName>"\r\n
                // \r\n
                // <value>\r\n
                partSize = boundaryBytes + 2
                         + ("Content-Disposition: form-data; name=\"".utf8.count
                            + safeName.utf8.count
                            + "\"".utf8.count
                            + 2)
                         + 2
                         + value.utf8.count
                         + 2

            case .file(let name, let filename, let mimeType, let data):
                let safeName = Self.sanitizeHeaderValue(name)
                let safeFilename = Self.sanitizeHeaderValue(filename)
                let safeMimeType = Self.sanitizeHeaderValue(mimeType)
                // --<boundary>\r\n
                // Content-Disposition: form-data; name="<safeName>"; filename="<safeFilename>"\r\n
                // Content-Type: <safeMimeType>\r\n
                // \r\n
                // <data>\r\n
                partSize = boundaryBytes + 2
                         + ("Content-Disposition: form-data; name=\"".utf8.count
                            + safeName.utf8.count
                            + "\"; filename=\"".utf8.count
                            + safeFilename.utf8.count
                            + "\"".utf8.count
                            + 2)
                         + ("Content-Type: ".utf8.count + safeMimeType.utf8.count + 2)
                         + 2
                         + data.count
                         + 2
            }
            // Note: sanitizeHeaderValue is called again in the build loop below.
            // This is intentional — the function is pure string manipulation and fast;
            // caching would add memory complexity for marginal benefit.
            let (newTotal, overflow) = totalSize.addingReportingOverflow(partSize)
            if overflow {
                throw OpenAIError.bufferOverflow(message: "Multipart body computation overflowed")
            }
            totalSize = newTotal
        }

        if totalSize > maxBodySize {
            throw OpenAIError.bufferOverflow(
                message: "Multipart body exceeded \(maxBodySize) bytes"
            )
        }

        // 3. Single-allocation Data build
        var body = Data(capacity: totalSize)

        let crlfBytes: [UInt8] = [0x0D, 0x0A]
        let boundaryLine = "--\(boundary)"
        let closingLine = "--\(boundary)--"

        for part in parts {
            body.append(contentsOf: boundaryLine.utf8)
            body.append(contentsOf: crlfBytes)

            switch part {
            case .field(let name, let value):
                let safeName = Self.sanitizeHeaderValue(name)
                let header = "Content-Disposition: form-data; name=\"\(safeName)\""
                body.append(contentsOf: header.utf8)
                body.append(contentsOf: crlfBytes)
                body.append(contentsOf: crlfBytes)
                body.append(contentsOf: value.utf8)
                body.append(contentsOf: crlfBytes)

            case .file(let name, let filename, let mimeType, let data):
                let safeName = Self.sanitizeHeaderValue(name)
                let safeFilename = Self.sanitizeHeaderValue(filename)
                let header = "Content-Disposition: form-data; name=\"\(safeName)\"; filename=\"\(safeFilename)\""
                let contentType = "Content-Type: \(Self.sanitizeHeaderValue(mimeType))"
                body.append(contentsOf: header.utf8)
                body.append(contentsOf: crlfBytes)
                body.append(contentsOf: contentType.utf8)
                body.append(contentsOf: crlfBytes)
                body.append(contentsOf: crlfBytes)
                body.append(data)
                body.append(contentsOf: crlfBytes)
            }
        }

        body.append(contentsOf: closingLine.utf8)
        body.append(contentsOf: crlfBytes)
        return body
    }

    // MARK: - Internal

    private enum Part: Sendable {
        case field(name: String, value: String)
        case file(name: String, filename: String, mimeType: String, data: Data)
    }
}

