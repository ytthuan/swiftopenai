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
        AsyncIterator(lineIterator: bytes.lines.makeAsyncIterator(), decoder: decoder)
    }
    #endif

    public struct AsyncIterator: AsyncIteratorProtocol {
        #if canImport(FoundationNetworking)
        private var iterator: AsyncThrowingStream<UInt8, Error>.AsyncIterator
        private let decoder: JSONDecoder
        private var buffer = Data(capacity: 4096)  // typical SSE line < 4KB
        /// Maximum SSE buffer size (10 MB) to prevent unbounded memory growth.
        private let maxBufferSize = 10 * 1024 * 1024

        init(iterator: AsyncThrowingStream<UInt8, Error>.AsyncIterator, decoder: JSONDecoder) {
            self.iterator = iterator
            self.decoder = decoder
        }
        #else
        private var lineIterator: AsyncLineSequence<URLSession.AsyncBytes>.AsyncIterator
        private let decoder: JSONDecoder
        /// Maximum single SSE line size (10 MB) to prevent unbounded memory from malformed data.
        private let maxLineSize = 10 * 1024 * 1024

        init(lineIterator: AsyncLineSequence<URLSession.AsyncBytes>.AsyncIterator, decoder: JSONDecoder) {
            self.lineIterator = lineIterator
            self.decoder = decoder
        }
        #endif

        public mutating func next() async throws -> T? {
            #if canImport(FoundationNetworking)
            let LF: UInt8 = 0x0A       // \n
            let CR: UInt8 = 0x0D       // \r
            let SP: UInt8 = 0x20       // ' '
            let HT: UInt8 = 0x09       // \t
            let COLON: UInt8 = 0x3A    // :

            while let byte = try await iterator.next() {
                if byte == LF {
                    defer { buffer.removeAll(keepingCapacity: true) }

                    // Trim trailing CR (CRLF endings)
                    if !buffer.isEmpty && buffer[buffer.index(before: buffer.endIndex)] == CR {
                        buffer.removeLast()
                    }

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

                    // Check for "data:" prefix (5 bytes: d=0x64 a=0x61 t=0x74 a=0x61 :=0x3A)
                    guard count >= 5,
                          buffer[start] == 0x64,
                          buffer[start + 1] == 0x61,
                          buffer[start + 2] == 0x74,
                          buffer[start + 3] == 0x61,
                          buffer[start + 4] == 0x3A
                    else { continue }

                    // Skip optional space after colon
                    var payloadStart = start + 5
                    if payloadStart < end && buffer[payloadStart] == SP {
                        payloadStart += 1
                    }

                    // Empty payload
                    if payloadStart >= end { continue }

                    let payloadEnd = end

                    // Check for "[DONE]" (6 bytes: [=0x5B D=0x44 O=0x4F N=0x4E E=0x45 ]=0x5D)
                    let payloadLen = payloadEnd - payloadStart
                    if payloadLen == 6,
                       buffer[payloadStart] == 0x5B,
                       buffer[payloadStart + 1] == 0x44,
                       buffer[payloadStart + 2] == 0x4F,
                       buffer[payloadStart + 3] == 0x4E,
                       buffer[payloadStart + 4] == 0x45,
                       buffer[payloadStart + 5] == 0x5D {
                        return nil
                    }

                    // Decode directly from buffer slice
                    return try decoder.decode(T.self, from: buffer[payloadStart..<payloadEnd])
                } else {
                    buffer.append(byte)
                    if buffer.count > maxBufferSize {
                        throw OpenAIError.bufferOverflow(
                            message: "SSE buffer exceeded \(maxBufferSize) bytes"
                        )
                    }
                }
            }
            return nil
            #else
            // Apple platforms: use AsyncLineSequence for one suspension per line
            while let line = try await lineIterator.next() {
                // Guard against single malformed mega-lines
                if line.utf8.count > maxLineSize {
                    throw OpenAIError.bufferOverflow(
                        message: "SSE line exceeded \(maxLineSize) bytes"
                    )
                }

                // Skip empty lines
                let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
                if trimmed.isEmpty { continue }

                // Skip comment lines
                if trimmed.hasPrefix(":") { continue }

                // Check for "data:" prefix
                guard trimmed.hasPrefix("data:") else { continue }

                // Extract payload after "data:"
                var payload = trimmed.dropFirst(5)
                if payload.first == " " { payload = payload.dropFirst() }

                if payload.isEmpty { continue }

                // Check for [DONE]
                if payload == "[DONE]" { return nil }

                // Decode from payload
                guard let data = String(payload).data(using: .utf8) else { continue }
                return try decoder.decode(T.self, from: data)
            }
            return nil
            #endif
        }
    }
}
