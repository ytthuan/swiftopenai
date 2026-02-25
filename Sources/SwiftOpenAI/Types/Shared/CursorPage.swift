import Foundation

/// A cursor-based page of results from the OpenAI API.
///
/// Wraps `ListResponse` and provides `AsyncSequence` iteration over pages.
public struct CursorPage<T: Codable & Sendable>: Codable, Sendable {
    public let data: [T]
    public let hasMore: Bool
    public let firstId: String?
    public let lastId: String?

    public init(data: [T], hasMore: Bool, firstId: String? = nil, lastId: String? = nil) {
        self.data = data
        self.hasMore = hasMore
        self.firstId = firstId
        self.lastId = lastId
    }

    init(response: ListResponse<T>) {
        self.data = response.data
        self.hasMore = response.hasMore ?? false
        self.firstId = response.firstId
        self.lastId = response.lastId
    }

    /// Returns an `AsyncSequence` that automatically fetches subsequent pages.
    ///
    /// Usage:
    /// ```swift
    /// let firstPage = try await client.fineTuning.jobs.list()
    /// for try await job in firstPage.autoPaginating(fetchNextPage: { after in
    ///     try await client.fineTuning.jobs.list(after: after)
    /// }) {
    ///     print(job.id)
    /// }
    /// ```
    public func autoPaginating(
        fetchNextPage: @escaping @Sendable (String) async throws -> CursorPage<T>
    ) -> AutoPaginatingSequence<T> {
        AutoPaginatingSequence(firstPage: self, fetchNextPage: fetchNextPage)
    }
}

// MARK: - AutoPaginatingSequence

/// An `AsyncSequence` that automatically paginates through all items across cursor-based pages.
public struct AutoPaginatingSequence<T: Codable & Sendable>: AsyncSequence, Sendable {
    public typealias Element = T

    private let firstPage: CursorPage<T>
    private let fetchNextPage: @Sendable (String) async throws -> CursorPage<T>

    public init(
        firstPage: CursorPage<T>,
        fetchNextPage: @escaping @Sendable (String) async throws -> CursorPage<T>
    ) {
        self.firstPage = firstPage
        self.fetchNextPage = fetchNextPage
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(currentPage: firstPage, fetchNextPage: fetchNextPage)
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private var currentPage: CursorPage<T>?
        private var index: Int = 0
        private let fetchNextPage: @Sendable (String) async throws -> CursorPage<T>

        init(
            currentPage: CursorPage<T>,
            fetchNextPage: @escaping @Sendable (String) async throws -> CursorPage<T>
        ) {
            self.currentPage = currentPage
            self.fetchNextPage = fetchNextPage
        }

        public mutating func next() async throws -> T? {
            while let page = currentPage {
                if index < page.data.count {
                    let item = page.data[index]
                    index += 1
                    return item
                }

                guard page.hasMore, let lastId = page.lastId else {
                    currentPage = nil
                    return nil
                }

                currentPage = try await fetchNextPage(lastId)
                index = 0
            }
            return nil
        }
    }
}
