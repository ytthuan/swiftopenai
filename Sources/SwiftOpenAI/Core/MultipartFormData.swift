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
    func encode() -> Data {
        var body = Data()
        let crlf = "\r\n"

        for part in parts {
            body.append("--\(boundary)\(crlf)")

            switch part {
            case .field(let name, let value):
                let safeName = Self.sanitizeHeaderValue(name)
                body.append("Content-Disposition: form-data; name=\"\(safeName)\"\(crlf)")
                body.append(crlf)
                body.append(value)
                body.append(crlf)

            case .file(let name, let filename, let mimeType, let data):
                let safeName = Self.sanitizeHeaderValue(name)
                let safeFilename = Self.sanitizeHeaderValue(filename)
                body.append("Content-Disposition: form-data; name=\"\(safeName)\"; filename=\"\(safeFilename)\"\(crlf)")
                body.append("Content-Type: \(mimeType)\(crlf)")
                body.append(crlf)
                body.append(data)
                body.append(crlf)
            }
        }

        body.append("--\(boundary)--\(crlf)")
        return body
    }

    // MARK: - Internal

    private enum Part: Sendable {
        case field(name: String, value: String)
        case file(name: String, filename: String, mimeType: String, data: Data)
    }
}

// MARK: - Data + String Append

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
