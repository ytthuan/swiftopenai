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
            // ASCII constants for byte-level parsing
            let LF: UInt8 = 0x0A       // \n
            let SP: UInt8 = 0x20       // ' '
            let HT: UInt8 = 0x09       // \t
            let COLON: UInt8 = 0x3A    // :

            while let byte = try await iterator.next() {
                if byte == LF {
                    defer { buffer.removeAll(keepingCapacity: true) }

                    // Skip empty lines
                    if buffer.isEmpty { continue }

                    // Find first non-whitespace byte
                    var start = buffer.startIndex
                    let end = buffer.endIndex
                    while start < end && (buffer[start] == SP || buffer[start] == HT) {
                        start += 1
                    }

                    // Empty after trim or comment line
                    let count = end - start
                    if count == 0 || buffer[start] == COLON { continue }

                    // Check for "data: " prefix (6 bytes: d=0x64 a=0x61 t=0x74 a=0x61 :=0x3A ' '=0x20)
                    guard count > 6,
                          buffer[start] == 0x64,
                          buffer[start + 1] == 0x61,
                          buffer[start + 2] == 0x74,
                          buffer[start + 3] == 0x61,
                          buffer[start + 4] == 0x3A,
                          buffer[start + 5] == 0x20
                    else { continue }

                    let payloadStart = start + 6
                    let payloadLen = end - payloadStart

                    // Check for "[DONE]" (6 bytes: [=0x5B D=0x44 O=0x4F N=0x4E E=0x45 ]=0x5D)
                    if payloadLen == 6,
                       buffer[payloadStart] == 0x5B,
                       buffer[payloadStart + 1] == 0x44,
                       buffer[payloadStart + 2] == 0x4F,
                       buffer[payloadStart + 3] == 0x4E,
                       buffer[payloadStart + 4] == 0x45,
                       buffer[payloadStart + 5] == 0x5D {
                        return nil
                    }

                    // Decode directly from buffer slice — no String round-trip
                    return try decoder.decode(T.self, from: buffer[payloadStart..<end])
                } else {
                    buffer.append(byte)
                }
            }
            return nil
        }
    }
}
