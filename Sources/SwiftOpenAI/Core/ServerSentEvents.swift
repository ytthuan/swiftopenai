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

    /// Iterates over SSE events parsed from a byte stream.
    ///
    /// AsyncSequence iteration is single-threaded by contract; the iterator is not safe
    /// to call from multiple tasks concurrently. `@unchecked Sendable` permits transfer
    /// between tasks but not concurrent use.
    public struct AsyncIterator: AsyncIteratorProtocol, @unchecked Sendable {
        #if canImport(FoundationNetworking)
        private var iterator: AsyncThrowingStream<UInt8, Error>.AsyncIterator
        #else
        private var iterator: URLSession.AsyncBytes.AsyncIterator
        #endif
        private let decoder: JSONDecoder
        private var buffer = Data(capacity: 4096)
        /// Maximum SSE buffer size (10 MB) to prevent unbounded memory growth.
        private let maxBufferSize = 10 * 1024 * 1024
        /// Set to `true` when the `[DONE]` sentinel is encountered.
        private var done = false

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

        // MARK: - Byte constants

        // Note: these cannot be `static let` because static stored properties
        // are not supported inside generic types in Swift.
        private var LF: UInt8 { 0x0A }       // \n
        private var CR: UInt8 { 0x0D }       // \r
        private var SP: UInt8 { 0x20 }       // ' '
        private var HT: UInt8 { 0x09 }       // \t
        private var COLON: UInt8 { 0x3A }    // :

        public mutating func next() async throws -> T? {
            while let byte = try await iterator.next() {
                if byte == LF {
                    if let result = try processCompleteLine() {
                        return result
                    }
                    if done { return nil }
                } else {
                    buffer.append(byte)
                    if buffer.count > maxBufferSize {
                        throw OpenAIError.bufferOverflow(
                            message: "SSE buffer exceeded \(maxBufferSize) bytes"
                        )
                    }
                }
            }

            // EOF flush: process any remaining data in the buffer as a final line
            if !buffer.isEmpty && !done {
                if let result = try processCompleteLine() {
                    return result
                }
            }
            return nil
        }

        // MARK: - Line Processing

        /// Processes the current buffer as a complete SSE line and resets it.
        ///
        /// - Returns: A decoded event if the line contained a valid `data:` payload,
        ///   or `nil` if the line should be skipped (empty, comment, non-data field).
        ///   Returns `nil` via early `return` for `[DONE]` sentinel — caller should
        ///   propagate this as stream termination.
        /// - Throws: `OpenAIError.decodingError` on JSON decode failure.
        private mutating func processCompleteLine() throws -> T? {
            defer { buffer.removeAll(keepingCapacity: true) }

            // Trim trailing CR (CRLF endings)
            if !buffer.isEmpty && buffer[buffer.index(before: buffer.endIndex)] == CR {
                buffer.removeLast()
            }

            // Skip empty lines
            if buffer.isEmpty { return nil }

            // Find first non-whitespace byte
            var start = buffer.startIndex
            let end = buffer.endIndex
            while start < end && (buffer[start] == SP || buffer[start] == HT) {
                start += 1
            }

            // Empty after trim or comment line
            let count = end - start
            if count == 0 || buffer[start] == COLON { return nil }

            // Check for "data:" prefix (5 bytes: d=0x64 a=0x61 t=0x74 a=0x61 :=0x3A)
            guard count >= 5,
                  buffer[start] == 0x64,
                  buffer[start + 1] == 0x61,
                  buffer[start + 2] == 0x74,
                  buffer[start + 3] == 0x61,
                  buffer[start + 4] == 0x3A
            else { return nil }

            // Skip optional space after colon
            var payloadStart = start + 5
            if payloadStart < end && buffer[payloadStart] == SP {
                payloadStart += 1
            }

            // Empty payload
            if payloadStart >= end { return nil }

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
                done = true
                return nil
            }

            // Decode directly from buffer slice
            do {
                return try decoder.decode(T.self, from: buffer[payloadStart..<payloadEnd])
            } catch {
                throw OpenAIError.decodingError(message: "\(error)")
            }
        }
    }
}
