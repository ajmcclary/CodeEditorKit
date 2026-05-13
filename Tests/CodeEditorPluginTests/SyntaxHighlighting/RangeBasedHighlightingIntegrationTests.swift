@testable import CodeEditorPlugin
import Foundation
import IssueReporting
import Testing

// MARK: - Test adapters

private struct TestElement: RangeStoreElement {
    let name: String
    var isEmpty: Bool { false }
}

@MainActor
private final class MockRangeHighlightProvider: RangeHighlightProviding {
    enum MockError: Error {
        case persistentFailure
    }

    var setupCalled = false
    var editCalls: [(range: NSRange, delta: Int)] = []
    var willEditCalls: [NSRange] = []
    var highlightResults: [NSRange: [HighlightedToken]] = [:]
    var nextInvalidation = IndexSet()
    var shouldThrow = false
    var queryCount = 0

    func setUp(textView _: CodeEditorView, language _: Language) {
        setupCalled = true
    }

    func willApplyEdit(textView _: CodeEditorView, range: NSRange) {
        willEditCalls.append(range)
    }

    func willApplyEdit(textView _: CodeEditorView, source _: String, range: NSRange) {
        willEditCalls.append(range)
    }

    func applyEdit(textView _: CodeEditorView, range: NSRange, delta: Int) async -> IndexSet {
        editCalls.append((range, delta))
        return nextInvalidation
    }

    func queryHighlights(textView _: CodeEditorView, range: NSRange) async throws -> [HighlightedToken] {
        queryCount += 1
        if shouldThrow {
            throw MockError.persistentFailure
        }
        return highlightResults[range] ?? []
    }
}

@MainActor
private final class RelativeRangeHighlighter: SyntaxHighlighter {
    func highlight(source _: String) -> [HighlightedToken] {
        [
            HighlightedToken(
                range: NSRange(location: 0, length: 3),
                type: .keyword,
                text: "let"
            )
        ]
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

    @Test("lower numeric provider priority wins over higher numeric priority")
    @MainActor
    func mergedRunsProviderPriorityWins() {
        let container = StyledRangeContainer(documentLength: 10)
        let highPriority = container.registerProvider(priority: 0)
        let lowPriority = container.registerProvider(priority: 10)

        container.applyHighlightResult(
            providerID: highPriority,
            highlights: [HighlightedToken(range: NSRange(location: 0, length: 6), type: .keyword, text: "high")],
            range: NSRange(location: 0, length: 10)
        )
        container.applyHighlightResult(
            providerID: lowPriority,
            highlights: [HighlightedToken(range: NSRange(location: 0, length: 6), type: .string, text: "low")],
            range: NSRange(location: 0, length: 10)
        )

        let runs = container.mergedRuns(in: NSRange(location: 0, length: 6))
        #expect(runs.count == 1)
        #expect(runs[0].length == 6)
        #expect(runs[0].value?.capture == "keyword")
    }

    @Test("lower priority provider fills gaps left by higher priority provider")
    @MainActor
    func mergedRunsLowerPriorityFillsGaps() {
        let container = StyledRangeContainer(documentLength: 10)
        let highPriority = container.registerProvider(priority: 0)
        let lowPriority = container.registerProvider(priority: 10)

        container.applyHighlightResult(
            providerID: highPriority,
            highlights: [HighlightedToken(range: NSRange(location: 0, length: 3), type: .keyword, text: "let")],
            range: NSRange(location: 0, length: 10)
        )
        container.applyHighlightResult(
            providerID: lowPriority,
            highlights: [HighlightedToken(range: NSRange(location: 3, length: 3), type: .string, text: "foo")],
            range: NSRange(location: 0, length: 10)
        )

        let runs = container.mergedRuns(in: NSRange(location: 0, length: 6))
        #expect(runs.map(\.length) == [3, 3])
        #expect(runs.map { $0.value?.capture } == ["keyword", "string"])
    }

    @Test("mergedRuns consumes partial provider runs without stretching them")
    @MainActor
    func mergedRunsConsumesPartialProviderRuns() {
        let container = StyledRangeContainer(documentLength: 10)
        let highPriority = container.registerProvider(priority: 0)
        let lowPriority = container.registerProvider(priority: 10)

        container.applyHighlightResult(
            providerID: highPriority,
            highlights: [HighlightedToken(range: NSRange(location: 0, length: 3), type: .keyword, text: "aaa")],
            range: NSRange(location: 0, length: 10)
        )
        container.applyHighlightResult(
            providerID: lowPriority,
            highlights: [HighlightedToken(range: NSRange(location: 0, length: 5), type: .identifier, text: "bbbbb")],
            range: NSRange(location: 0, length: 10)
        )

        let runs = container.mergedRuns(in: NSRange(location: 0, length: 10))
        #expect(runs.map(\.length) == [3, 2, 5])
        #expect(runs.map { $0.value?.capture } == ["keyword", "identifier", nil])
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
        #expect(provider.visibleIndices.isEmpty)
    }
}

@Suite("HighlightProviderState")
struct HighlightProviderStateTests {
    @Test("nextRange is nil before any visible range is set")
    @MainActor
    func nextRangeNilBeforeVisibleRange() throws {
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
        #expect(state.nextRange() == nil)
    }

    @Test("nextRange returns the full contiguous visible range up to maxChunk")
    @MainActor
    func nextRangeUsesContiguousVisibleRun() {
        let mock = MockRangeHighlightProvider()
        let container = StyledRangeContainer(documentLength: 100)
        let textView = CodeEditorView()
        let state = HighlightProviderState(
            provider: mock,
            providerID: 0,
            container: container,
            textView: textView,
            documentLength: 100,
            maxChunk: 20
        )

        state.updateVisibleSet(IndexSet(integersIn: 10..<21), schedulesHighlighting: false)

        #expect(state.nextRange() == NSRange(location: 10, length: 11))
    }

    @Test("nextRange clamps visible chunks to maxChunk")
    @MainActor
    func nextRangeClampsToMaxChunk() {
        let mock = MockRangeHighlightProvider()
        let container = StyledRangeContainer(documentLength: 100)
        let textView = CodeEditorView()
        let state = HighlightProviderState(
            provider: mock,
            providerID: 0,
            container: container,
            textView: textView,
            documentLength: 100,
            maxChunk: 20
        )

        state.updateVisibleSet(IndexSet(integersIn: 10..<80), schedulesHighlighting: false)

        #expect(state.nextRange() == NSRange(location: 10, length: 20))
    }

    @Test("persistent provider errors are not retried in a tight loop")
    @MainActor
    func persistentProviderErrorIsMarkedHandled() async {
        let mock = MockRangeHighlightProvider()
        mock.shouldThrow = true
        let container = StyledRangeContainer(documentLength: 100)
        let textView = CodeEditorView()
        let state = HighlightProviderState(
            provider: mock,
            providerID: 0,
            container: container,
            textView: textView,
            documentLength: 100,
            maxChunk: 20
        )

        await withExpectedIssue("Provider errors are surfaced through IssueReporting") {
            state.updateVisibleSet(IndexSet(integersIn: 10..<21), schedulesHighlighting: false)
            await state.highlightInvalidRanges()
            try? await Task.sleep(for: .milliseconds(20))
            state.cancel()
        }

        #expect(mock.queryCount == 1)
        #expect(state.nextRange() == nil)
    }
}

@Suite("SyntaxHighlighterRangeAdapter")
struct SyntaxHighlighterRangeAdapterTests {
    @Test("queryHighlights shifts substring-relative UTF-16 ranges after non-ASCII prefix")
    @MainActor
    func queryHighlightsShiftsUTF16Ranges() async throws {
        let textView = CodeEditorView()
        #if canImport(AppKit)
        textView.string = "🙂\nlet value = 1"
        #else
        textView.text = "🙂\nlet value = 1"
        #endif

        let adapter = SyntaxHighlighterRangeAdapter(highlighter: RelativeRangeHighlighter())
        let tokens = try await adapter.queryHighlights(
            textView: textView,
            range: NSRange(location: 3, length: 3)
        )

        #expect(tokens.map(\.range) == [NSRange(location: 3, length: 3)])
    }
}

@Suite("Range-based highlighting production wiring")
struct RangeBasedHighlightingWiringTests {
    @Test("range-based highlighting flag installs style data source")
    @MainActor
    func flagInstallsStyleDataSource() {
        let textView = CodeEditorView()
        var config = EditorConfiguration()
        config.performance.usesRangeBasedHighlighting = true
        textView.configuration = config
        textView.applyConfiguration()

        #expect(textView.rangeBasedHighlightingStyleDataSourceForTesting != nil)
    }

    @Test("supplemental provider registered after initialization receives edits")
    @MainActor
    func supplementalProviderReceivesEdits() async throws {
        let textView = CodeEditorView()
        #if canImport(AppKit)
        textView.string = "let value = 1"
        #else
        textView.text = "let value = 1"
        #endif
        // CodeEditorView defers its post-edit fan-out one runloop hop so it
        // doesn't trip NSTextContentStorageBreakOnEnumerateWhileEditing
        // (see CodeEditorView+SyntaxHighlightingExtensions.swift). Drain the
        // deferred publish from the initial text seed before constructing
        // the controller so its observers only see the synthetic edit
        // dispatched below.
        try await Task.sleep(for: .milliseconds(1))

        let primary = MockRangeHighlightProvider()
        let supplemental = MockRangeHighlightProvider()
        let controller = RangeBasedHighlightingController(
            textView: textView,
            language: .swift,
            externalProvider: primary
        )
        defer { controller.detach() }

        controller.registerSupplementalProvider(supplemental, priority: -1)
        controller.textStorageDidApplyEdit(TextEditEvent(
            editedRange: NSRange(location: 0, length: 0),
            changeInLength: 1,
            documentLength: textView.textStorage?.length ?? 0,
            editedCharacters: true
        ))

        try await Task.sleep(for: .milliseconds(20))

        #expect(primary.editCalls.count == 1)
        #expect(supplemental.editCalls.count == 1)
        #expect(primary.willEditCalls.count == 1)
        #expect(supplemental.willEditCalls.count == 1)
    }

    @Test("unregistered supplemental provider stops receiving edits")
    @MainActor
    func unregisteredSupplementalProviderStopsReceivingEdits() async throws {
        let textView = CodeEditorView()
        #if canImport(AppKit)
        textView.string = "let value = 1"
        #else
        textView.text = "let value = 1"
        #endif
        // Drain the deferred publish before constructing the controller —
        // see comment on `supplementalProviderReceivesEdits` above.
        try await Task.sleep(for: .milliseconds(1))

        let primary = MockRangeHighlightProvider()
        let supplemental = MockRangeHighlightProvider()
        let controller = RangeBasedHighlightingController(
            textView: textView,
            language: .swift,
            externalProvider: primary
        )
        defer { controller.detach() }

        controller.registerSupplementalProvider(supplemental, priority: -1)
        controller.unregisterSupplementalProvider(supplemental)
        controller.textStorageDidApplyEdit(TextEditEvent(
            editedRange: NSRange(location: 0, length: 0),
            changeInLength: 1,
            documentLength: textView.textStorage?.length ?? 0,
            editedCharacters: true
        ))

        try await Task.sleep(for: .milliseconds(20))

        #expect(primary.editCalls.count == 1)
        #expect(supplemental.editCalls.isEmpty)
        #expect(supplemental.willEditCalls.isEmpty)
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
