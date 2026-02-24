import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Parses Server-Sent Events (SSE) from a streaming HTTP response.
///
/// Conforms to `AsyncSequence` to allow `for await event in stream { ... }` usage.
public struct ServerSentEventsStream<T: Decodable & Sendable>: AsyncSequence, Sendable {
    public typealias Element = T

    #if canImport(FoundationNetworking)
    private let byteStream: AsyncThrowingStream<UInt8, Error>
    private let decoder: JSONDecoder

    init(byteStream: AsyncThrowingStream<UInt8, Error>, decoder: JSONDecoder) {
        self.byteStream = byteStream
        self.decoder = decoder
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: byteStream.makeAsyncIterator(), decoder: decoder)
    }
    #else
    private let bytes: URLSession.AsyncBytes
    private let decoder: JSONDecoder

    init(bytes: URLSession.AsyncBytes, response: URLResponse, decoder: JSONDecoder) {
        self.bytes = bytes
        self.decoder = decoder
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: bytes.makeAsyncIterator(), decoder: decoder)
    }
    #endif

    public struct AsyncIterator: AsyncIteratorProtocol {
        #if canImport(FoundationNetworking)
        private var iterator: AsyncThrowingStream<UInt8, Error>.AsyncIterator
        #else
        private var iterator: URLSession.AsyncBytes.AsyncIterator
        #endif
        private let decoder: JSONDecoder
        private var buffer = Data()

        #if canImport(FoundationNetworking)
        init(iterator: AsyncThrowingStream<UInt8, Error>.AsyncIterator, decoder: JSONDecoder) {
            self.iterator = iterator
            self.decoder = decoder
        }
        #else
        init(iterator: URLSession.AsyncBytes.AsyncIterator, decoder: JSONDecoder) {
            self.iterator = iterator
            self.decoder = decoder
        }
        #endif

        public mutating func next() async throws -> T? {
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
