#if canImport(AppKit)
import AppKit
import CodeEditorLanguages
@testable import CodeEditorSymbols
@testable import CodeEditorView
import XCTest

/// Symbols from a large document must never be indexed through recursion
/// whose depth follows the input: a ~200 KB JSON put ~8,000 symbols on one
/// right-hand spine of `SymbolRangeIndex`, and inserting them recursed until
/// the main thread's stack overflowed.
@MainActor
final class SymbolIndexDepthTests: XCTestCase {
    /// Runs `body` on a thread with a 256 KB stack (the main thread has 8 MB),
    /// so recursion that grows with the input fails here instead of passing
    /// on the main thread for a while.
    nonisolated private func onSmallStack(_ body: @escaping @Sendable () -> Void) {
        let done = DispatchSemaphore(value: 0)
        let thread = Thread {
            body()
            done.signal()
        }
        thread.stackSize = 256 * 1_024
        thread.start()
        done.wait()
    }

    private static func json(entries: Int, pretty: Bool) -> String {
        let entry = pretty
            ? "  {\n    \"key\": [1, 2, {\"inner\": \"v\"}],\n    \"other\": true\n  }"
            : #"{"key": [1, 2, {"inner": "v"}], "other": true}"#
        return "[" + (pretty ? "\n" : "")
            + Array(repeating: entry, count: entries).joined(separator: pretty ? ",\n" : ",")
            + (pretty ? "\n" : "") + "]"
    }

    // MARK: - The index and the tree, off the main thread on a small stack

    func testTheIndexHandlesManySymbolsAtOneLocationOnASmallStack() {
        onSmallStack {
            let index = SymbolRangeIndex<Int>()
            let entries = (0..<200_000).map { (NSRange(location: 0, length: 10 + $0 % 7), $0) }
            index.replaceAll(with: entries)
            index.insert(range: NSRange(location: 5, length: 1), value: -1)
            let found = index.findContaining(location: 3)
            XCTAssertEqual(found.count, 200_000)
        }
    }

    func testIncrementalInsertsInAscendingOrderStayShallowOnASmallStack() {
        onSmallStack {
            let index = SymbolRangeIndex<Int>()
            for location in 0..<100_000 {
                index.insert(range: NSRange(location: location, length: 2), value: location)
            }
            // Containment includes the end (as before): [49_998, 50_000] holds 50_000.
            XCTAssertEqual(index.findContaining(location: 50_000).sorted(), [49_998, 49_999, 50_000])
        }
    }

    func testTheSymbolTreeOfDeeplyNestedSymbolsBuildsOnASmallStack() {
        onSmallStack {
            // 20,000 objects, each containing the next.
            let count = 20_000
            let symbols = (0..<count).map { depth in
                DocumentSymbol(
                    name: "o\(depth)",
                    kind: .object,
                    range: NSRange(location: depth, length: 2 * (count - depth)),
                    selectionRange: NSRange(location: depth, length: 1)
                )
            }
            let tree = SymbolNavigator.buildSymbolTree(from: symbols)
            let flattened = SymbolNavigator.flatten(tree)
            XCTAssertEqual(flattened.count, count)
            XCTAssertEqual(tree.count, 1)
        }
    }

    // MARK: - The whole pipeline on the main thread

    private func assertDocumentIndexesWithoutCrashing(_ text: String) async throws {
        let view = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        view.language = .json
        view.string = text
        let navigator = SymbolNavigator()
        navigator.attach(to: view)
        let deadline = Date().addingTimeInterval(60)
        while navigator.symbols.isEmpty, Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertFalse(navigator.symbols.isEmpty)
        XCTAssertLessThanOrEqual(SymbolNavigator.flatten(navigator.symbols).count, SymbolNavigator.maximumIndexedSymbols)
        view.setSelectedRange(NSRange(location: text.utf16.count / 2, length: 0))
        navigator.updateBreadcrumbs()
        _ = navigator.symbol(at: text.utf16.count / 2)
    }

    func testA200KBSingleLineJSONIndexes() async throws {
        try await assertDocumentIndexesWithoutCrashing(Self.json(entries: 4_300, pretty: false))
    }

    func testA200KBPrettyJSONIndexes() async throws {
        try await assertDocumentIndexesWithoutCrashing(Self.json(entries: 3_200, pretty: true))
    }

    func testA2MBSingleLineJSONIndexes() async throws {
        try await assertDocumentIndexesWithoutCrashing(Self.json(entries: 43_000, pretty: false))
    }

    func testA2MBPrettyJSONIndexes() async throws {
        try await assertDocumentIndexesWithoutCrashing(Self.json(entries: 32_000, pretty: true))
    }
}
#endif
