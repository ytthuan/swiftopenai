import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Parses Server-Sent Events (SSE) from a streaming HTTP response.
///
/// Conforms to `AsyncSequence` to allow `for await event in stream { ... }` usage.
struct ServerSentEventsStream<T: Decodable & Sendable>: AsyncSequence, Sendable {
    typealias Element = T

    private let bytes: URLSession.AsyncBytes
    private let response: URLResponse
    private let decoder: JSONDecoder

    init(bytes: URLSession.AsyncBytes, response: URLResponse, decoder: JSONDecoder) {
        self.bytes = bytes
        self.response = response
        self.decoder = decoder
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(bytes: bytes, decoder: decoder)
    }

    struct AsyncIterator: AsyncIteratorProtocol {
        private var iterator: URLSession.AsyncBytes.Iterator
        private let decoder: JSONDecoder
        private var buffer = Data()

        init(bytes: URLSession.AsyncBytes, decoder: JSONDecoder) {
            self.iterator = bytes.makeAsyncIterator()
            self.decoder = decoder
        }

        mutating func next() async throws -> T? {
            while let byte = try await iterator.next() {
                // Collect bytes until we hit a newline
                if byte == UInt8(ascii: "\n") {
                    let line = String(decoding: buffer, as: UTF8.self)
                    buffer.removeAll(keepingCapacity: true)

                    // Skip empty lines and comments
                    let trimmed = line.trimmingCharacters(in: CharacterSet.whitespaces)
                    if trimmed.isEmpty || trimmed.hasPrefix(":") {
                        continue
                    }

                    // Parse "data: ..." lines
                    if trimmed.hasPrefix("data: ") {
                        let payload = String(trimmed.dropFirst(6))

                        // "[DONE]" signals end of stream
                        if payload == "[DONE]" {
                            return nil
                        }

                        guard let data = payload.data(using: String.Encoding.utf8) else { continue }
                        return try decoder.decode(T.self, from: data)
                    }
                } else {
                    buffer.append(byte)
                }
            }
            return nil
        }
    }
}
