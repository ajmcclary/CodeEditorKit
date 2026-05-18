#if canImport(AppKit)
import CodeEditorPlugin
@testable import CodeEditorSample
import CodeEditorSearch
import Foundation
import Testing

@MainActor
@Suite("ProjectSearchModel")
struct ProjectSearchModelTests {
    @Test("empty query clears results without calling search")
    func emptyQueryClears() async {
        let stub = StubProjectSearchProvider()
        let model = ProjectSearchModel(adapter: stub)

        model.query = ""
        await model.runSearch()

        #expect(stub.searchCalls.isEmpty)
        #expect(model.results.isEmpty)
    }

    @Test("non-empty query invokes the adapter and stores results")
    func nonEmptyQuerySearches() async {
        let stub = StubProjectSearchProvider()
        let result = ProjectSearchResult(
            fileURL: URL(fileURLWithPath: "/tmp/x.swift"),
            lineNumber: 3,
            column: 5,
            matchedText: "foo",
            contextLine: "let foo = 1"
        )
        stub.setResults([result])
        let model = ProjectSearchModel(adapter: stub)

        model.query = "foo"
        await model.runSearch()

        #expect(stub.searchCalls.map(\.query) == ["foo"])
        #expect(model.results.count == 1)
    }

    @Test("toggle changes trigger runSearch from the host")
    func toggleTriggersSearch() async {
        let stub = StubProjectSearchProvider()
        let model = ProjectSearchModel(adapter: stub)
        model.query = "foo"
        await model.runSearch()
        let baseline = stub.searchCalls.count

        model.caseSensitive = true
        await model.runSearch()

        #expect(stub.searchCalls.count == baseline + 1)
        #expect(stub.searchCalls.last?.options.caseSensitive == true)
    }

    @Test("adapter error sets the error status")
    func adapterErrorStored() async {
        let stub = StubProjectSearchProvider()
        struct Boom: Error, LocalizedError {
            var errorDescription: String? { "regex bad" }
        }
        stub.setError(Boom())
        let model = ProjectSearchModel(adapter: stub)

        model.query = "foo"
        await model.runSearch()

        if case let .error(message) = model.status {
            #expect(message == "regex bad")
        } else {
            Issue.record("expected .error status, got \(model.status)")
        }
    }

    @Test("extensionFilter parsing splits on comma/whitespace and lowercases")
    func extensionFilterParsing() async {
        let stub = StubProjectSearchProvider()
        let model = ProjectSearchModel(adapter: stub)
        model.query = "foo"
        model.extensionFilter = "Swift, MD .toml"
        await model.runSearch()

        let exts = stub.searchCalls.last?.options.fileExtensions ?? []
        #expect(Set(exts) == ["swift", "md", "toml"])
    }

    @Test("setRoot(nil) cancels and clears the index")
    func setRootNilClears() async {
        let stub = StubProjectSearchProvider()
        let model = ProjectSearchModel(adapter: stub)
        await model.setRoot(nil)

        #expect(model.results.isEmpty)
        #expect(model.status == .idle)
    }
}
#endif
