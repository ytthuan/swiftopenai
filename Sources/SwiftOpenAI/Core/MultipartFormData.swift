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
    /// Uses `ContiguousArray<UInt8>` internally to avoid intermediate `Data` allocations.
    func encode() -> Data {
        let boundaryBytes = "--\(boundary)".utf8.count
        let overhead = parts.count * (boundaryBytes + 200) + boundaryBytes + 10
        let dataSize = parts.reduce(0) { total, part in
            switch part {
            case .field(_, let value): return total + value.utf8.count
            case .file(_, _, _, let data): return total + data.count
            }
        }

        var builder = ContiguousArray<UInt8>()
        builder.reserveCapacity(overhead + dataSize)

        let crlfBytes: [UInt8] = [0x0D, 0x0A]
        let boundaryLine = "--\(boundary)"
        let closingLine = "--\(boundary)--"

        for part in parts {
            builder.append(contentsOf: boundaryLine.utf8)
            builder.append(contentsOf: crlfBytes)

            switch part {
            case .field(let name, let value):
                let safeName = Self.sanitizeHeaderValue(name)
                let header = "Content-Disposition: form-data; name=\"\(safeName)\""
                builder.append(contentsOf: header.utf8)
                builder.append(contentsOf: crlfBytes)
                builder.append(contentsOf: crlfBytes)
                builder.append(contentsOf: value.utf8)
                builder.append(contentsOf: crlfBytes)

            case .file(let name, let filename, let mimeType, let data):
                let safeName = Self.sanitizeHeaderValue(name)
                let safeFilename = Self.sanitizeHeaderValue(filename)
                let header = "Content-Disposition: form-data; name=\"\(safeName)\"; filename=\"\(safeFilename)\""
                let contentType = "Content-Type: \(Self.sanitizeHeaderValue(mimeType))"
                builder.append(contentsOf: header.utf8)
                builder.append(contentsOf: crlfBytes)
                builder.append(contentsOf: contentType.utf8)
                builder.append(contentsOf: crlfBytes)
                builder.append(contentsOf: crlfBytes)
                builder.append(contentsOf: data)
                builder.append(contentsOf: crlfBytes)
            }
        }

        builder.append(contentsOf: closingLine.utf8)
        builder.append(contentsOf: crlfBytes)
        return Data(builder)
    }

    // MARK: - Internal

    private enum Part: Sendable {
        case field(name: String, value: String)
        case file(name: String, filename: String, mimeType: String, data: Data)
    }
}

