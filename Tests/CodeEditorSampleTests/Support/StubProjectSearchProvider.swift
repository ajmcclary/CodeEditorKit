import CodeEditorPlugin
import Foundation
import os

/// Test double for ProjectSearchProvider. Records calls, returns
/// pre-canned results, and can be configured to throw.
final class StubProjectSearchProvider: ProjectSearchProvider, @unchecked Sendable {
    private struct State {
        var indexedURLs: [URL] = []
        var cancelCount = 0
        var clearCount = 0
        var searchCalls: [(query: String, options: ProjectSearchOptions)] = []
        var resultsToReturn: [ProjectSearchResult] = []
        var errorToThrow: Error?
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    var indexedURLs: [URL] { state.withLock { $0.indexedURLs } }
    var cancelCount: Int { state.withLock { $0.cancelCount } }
    var clearCount: Int { state.withLock { $0.clearCount } }
    var searchCalls: [(query: String, options: ProjectSearchOptions)] {
        state.withLock { $0.searchCalls }
    }

    func setResults(_ results: [ProjectSearchResult]) {
        state.withLock { $0.resultsToReturn = results }
    }

    func setError(_ error: Error?) {
        state.withLock { $0.errorToThrow = error }
    }

    func indexFiles(urls: [URL]) async throws {
        state.withLock { $0.indexedURLs = urls }
    }

    func search(query: String, options: ProjectSearchOptions) async throws -> [ProjectSearchResult] {
        let snapshot: ([ProjectSearchResult], Error?) = state.withLock {
            $0.searchCalls.append((query, options))
            return ($0.resultsToReturn, $0.errorToThrow)
        }
        if let err = snapshot.1 { throw err }
        return snapshot.0
    }

    func cancelSearch() {
        state.withLock { $0.cancelCount += 1 }
    }

    func clearIndex() {
        state.withLock {
            $0.indexedURLs = []
            $0.clearCount += 1
        }
    }
}
