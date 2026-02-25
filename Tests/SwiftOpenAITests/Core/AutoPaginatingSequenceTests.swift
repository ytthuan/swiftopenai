import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SwiftOpenAI

/// Simple Codable type for pagination tests.
private struct Item: Codable, Sendable, Equatable {
    let id: String
}

private struct TestError: Error {
    let message: String
}

@Suite struct AutoPaginatingSequenceTests {

    @Test func iteratesAllItemsAcrossMultiplePages() async throws {
        let page1 = CursorPage(data: [Item(id: "a"), Item(id: "b")], hasMore: true, firstId: "a", lastId: "b")
        let page2 = CursorPage(data: [Item(id: "c"), Item(id: "d")], hasMore: true, firstId: "c", lastId: "d")
        let page3 = CursorPage(data: [Item(id: "e")], hasMore: false, firstId: "e", lastId: "e")

        nonisolated(unsafe) var fetchCount = 0
        let sequence = page1.autoPaginating { @Sendable after -> CursorPage<Item> in
            fetchCount += 1
            if after == "b" { return page2 }
            if after == "d" { return page3 }
            throw TestError(message: "unexpected cursor: \(after)")
        }

        var collected: [String] = []
        for try await item in sequence {
            collected.append(item.id)
        }

        #expect(collected == ["a", "b", "c", "d", "e"])
        #expect(fetchCount == 2)
    }

    @Test func singlePageDoesNotFetchNext() async throws {
        let page = CursorPage(data: [Item(id: "x")], hasMore: false, firstId: "x", lastId: "x")

        nonisolated(unsafe) var fetchCalled = false
        let sequence = page.autoPaginating { @Sendable _ -> CursorPage<Item> in
            fetchCalled = true
            throw TestError(message: "should not be called")
        }

        var collected: [String] = []
        for try await item in sequence {
            collected.append(item.id)
        }

        #expect(collected == ["x"])
        #expect(!fetchCalled)
    }

    @Test func emptyFirstPageReturnsNoItems() async throws {
        let page = CursorPage<Item>(data: [], hasMore: false, firstId: nil, lastId: nil)

        let sequence = page.autoPaginating { _ -> CursorPage<Item> in
            throw TestError(message: "should not be called")
        }

        var collected: [Item] = []
        for try await item in sequence {
            collected.append(item)
        }

        #expect(collected.isEmpty)
    }

    @Test func hasMoreTrueButNoLastIdStopsPagination() async throws {
        let page = CursorPage(data: [Item(id: "z")], hasMore: true, firstId: "z", lastId: nil)

        let sequence = page.autoPaginating { _ -> CursorPage<Item> in
            throw TestError(message: "should not be called")
        }

        var collected: [String] = []
        for try await item in sequence {
            collected.append(item.id)
        }

        #expect(collected == ["z"])
    }
}
