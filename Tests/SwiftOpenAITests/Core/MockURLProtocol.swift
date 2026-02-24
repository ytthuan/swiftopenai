import Foundation
@testable import SwiftOpenAI

/// A URLProtocol subclass that intercepts all requests and returns mocked responses.
/// Used in tests to avoid hitting the real OpenAI API.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {

    /// The mock response to return. Set before each test.
    nonisolated(unsafe) static var mockResponse: (Data, HTTPURLResponse)?

    /// Optionally capture the last request for assertion.
    nonisolated(unsafe) static var lastRequest: URLRequest?

    /// Captured request body (URLSession strips httpBody, so we read from httpBodyStream).
    nonisolated(unsafe) static var lastRequestBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request

        // Capture body from httpBody or httpBodyStream
        if let body = request.httpBody {
            Self.lastRequestBody = body
        } else if let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
            defer { buffer.deallocate() }
            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: 4096)
                if read > 0 {
                    data.append(buffer, count: read)
                } else {
                    break
                }
            }
            stream.close()
            Self.lastRequestBody = data
        }

        if let (data, response) = Self.mockResponse {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// Reset mock state between tests.
    static func reset() {
        mockResponse = nil
        lastRequest = nil
        lastRequestBody = nil
    }
}
