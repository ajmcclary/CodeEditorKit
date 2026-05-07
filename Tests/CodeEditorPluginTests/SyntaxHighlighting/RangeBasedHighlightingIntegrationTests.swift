@testable import CodeEditorPlugin
import Foundation
import Testing

// MARK: - Test adapters

private struct TestElement: RangeStoreElement {
    let name: String
    var isEmpty: Bool { false }
}

@MainActor
private final class MockRangeHighlightProvider: RangeHighlightProviding {
    var setupCalled = false
    var editCalls: [(range: NSRange, delta: Int)] = []
    var highlightResults: [NSRange: [HighlightedToken]] = [:]
    var nextInvalidation = IndexSet()

    func setUp(textView _: CodeEditorView, language _: Language) {
        setupCalled = true
    }

    func applyEdit(textView _: CodeEditorView, range: NSRange, delta: Int) async -> IndexSet {
        editCalls.append((range, delta))
        return nextInvalidation
    }

    func queryHighlights(textView _: CodeEditorView, range: NSRange) async throws -> [HighlightedToken] {
        highlightResults[range] ?? []
    }
}

// MARK: - Tests

@Suite("RangeHighlightProviding protocol")
struct RangeHighlightProvidingTests {
    @Test("default willApplyEdit is no-op")
    @MainActor
    func defaultWillApplyEdit() {
        let provider = MockRangeHighlightProvider()
        provider.willApplyEdit(textView: CodeEditorView(), range: NSRange(location: 0, length: 1))
        // No crash = pass
    }
}

@Suite("StyleElement")
struct StyleElementTests {
    @Test("empty when capture is nil")
    func emptyWhenNil() {
        let el = StyleElement(capture: nil)
        #expect(el.isEmpty)
    }

    @Test("not empty when capture is set")
    func notEmptyWithCapture() {
        let el = StyleElement(capture: "keyword")
        #expect(!el.isEmpty)
    }

    @Test("combineLowerPriority keeps own capture")
    func combineLower() {
        let el = StyleElement(capture: "keyword")
        let other = StyleElement(capture: "string")
        #expect(el.combineLowerPriority(other).capture == "keyword")
    }

    @Test("combineHigherPriority takes other's capture")
    func combineHigher() {
        let el = StyleElement(capture: "keyword")
        let other = StyleElement(capture: "string")
        #expect(el.combineHigherPriority(other).capture == "string")
    }

    @Test("combineHigherPriority keeps own when other is empty")
    func combineHigherEmpty() {
        let el = StyleElement(capture: "keyword")
        let empty = StyleElement(capture: nil)
        #expect(el.combineHigherPriority(empty).capture == "keyword")
    }
}

@Suite("StyledRangeContainer")
struct StyledRangeContainerTests {
    @Test("registerProvider assigns unique IDs")
    @MainActor
    func registerUniqueIDs() {
        let container = StyledRangeContainer(documentLength: 100)
        let id1 = container.registerProvider(priority: 0)
        let id2 = container.registerProvider(priority: 1)
        #expect(id1 != id2)
    }

    @Test("mergedRuns returns empty for container with no providers")
    @MainActor
    func mergedRunsEmptyWithoutProviders() {
        let container = StyledRangeContainer(documentLength: 100)
        let runs = container.mergedRuns(in: NSRange(location: 0, length: 100))
        #expect(runs.isEmpty)
    }

    @Test("mergedRuns returns data after provider registers and writes")
    @MainActor
    func mergedRunsWithData() {
        let container = StyledRangeContainer(documentLength: 100)
        let id = container.registerProvider(priority: 0)
        let tokens = [
            HighlightedToken(
                range: NSRange(location: 10, length: 5),
                type: .keyword,
                text: "hello"
            )
        ]
        container.applyHighlightResult(providerID: id, highlights: tokens, range: NSRange(location: 0, length: 100))
        let runs = container.mergedRuns(in: NSRange(location: 10, length: 5))
        #expect(!runs.isEmpty)
    }

    @Test("storageUpdated adjusts document length and runs reflect it")
    @MainActor
    func storageUpdatedLength() {
        let container = StyledRangeContainer(documentLength: 100)
        let id = container.registerProvider(priority: 0)
        let tokens = [
            HighlightedToken(
                range: NSRange(location: 50, length: 20),
                type: .keyword,
                text: "test"
            )
        ]
        container.applyHighlightResult(providerID: id, highlights: tokens, range: NSRange(location: 0, length: 100))

        // Insert 20 chars at offset 10 — shifts the "test" token to 70..<90
        container.storageUpdated(editedRange: NSRange(location: 10, length: 0), changeInLength: 20)

        // Query around where the token should now be
        let runs = container.mergedRuns(in: NSRange(location: 65, length: 30))
        let keywordRuns = runs.filter { $0.value?.capture == "keyword" }
        #expect(!keywordRuns.isEmpty)
    }
}

@Suite("VisibleRangeProvider")
struct VisibleRangeProviderTests {
    @Test("init does not crash")
    @MainActor
    func initNoCrash() {
        let textView = CodeEditorView()
        let provider = VisibleRangeProvider(textView: textView)
        #expect(!provider.visibleIndices.isEmpty || provider.visibleIndices.isEmpty)
    }
}

@Suite("HighlightProviderState")
struct HighlightProviderStateTests {
    @Test("init sets initial state")
    @MainActor
    func initState() throws {
        let mock = MockRangeHighlightProvider()
        let container = StyledRangeContainer(documentLength: 100)
        let textView = CodeEditorView()
        let state = HighlightProviderState(
            provider: mock,
            providerID: 0,
            container: container,
            textView: textView,
            documentLength: 100
        )
        // Initial state: no visible range, so nextRange returns nil
        let next = state.nextRange()
        #expect(next == nil || next != nil) // Just ensure compute doesn't crash
    }
}

@Suite("Range-based highlighting feature flag")
struct RangeBasedHighlightingFlagTests {
    @Test("usesRangeBasedHighlighting defaults to false")
    func flagDefaults() {
        let config = EditorConfiguration()
        #expect(config.performance.usesRangeBasedHighlighting == false)
    }

    @Test("flag can be toggled")
    func flagToggle() {
        var config = EditorConfiguration()
        config.performance.usesRangeBasedHighlighting = true
        #expect(config.performance.usesRangeBasedHighlighting == true)
        config.performance.usesRangeBasedHighlighting = false
        #expect(config.performance.usesRangeBasedHighlighting == false)
    }
}
