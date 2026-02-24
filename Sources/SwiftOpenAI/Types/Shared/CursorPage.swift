import Foundation

/// A cursor-based page of results from the OpenAI API.
///
/// Wraps `ListResponse` and provides `AsyncSequence` iteration over pages.
public struct CursorPage<T: Codable & Sendable>: Sendable {
    public let data: [T]
    public let hasMore: Bool
    public let firstId: String?
    public let lastId: String?

    init(response: ListResponse<T>) {
        self.data = response.data
        self.hasMore = response.hasMore ?? false
        self.firstId = response.firstId
        self.lastId = response.lastId
    }
}
