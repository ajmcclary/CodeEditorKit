@testable import CodeEditorPlugin
import XCTest

@MainActor
final class FeatureBehaviorTests: CleanupTestCase {
    func testSearchReplaceFindsAndReplacesAllMatches() async {
        let editor = createCodeEditorView()
        editor.text = """
        let foo = 1
        foo += 1
        print(foo)
        """

        var options = SearchOptions()
        options.highlightResults = false
        options.flashResult = false

        let engine = SearchReplaceEngine()
        engine.attach(to: editor)

        let results = await engine.findAll(pattern: "foo", options: options)
        XCTAssertEqual(results.map(\.lineNumber), [1, 2, 3])
        XCTAssertEqual(engine.searchStatistics.totalMatches, 3)

        let replacementCount = await engine.replaceAll(pattern: "foo", with: "bar", options: options)
        XCTAssertEqual(replacementCount, 3)
        let editedText = editor.text ?? ""
        XCTAssertFalse(editedText.contains("foo"))
        XCTAssertTrue(editedText.contains("print(bar)"))
    }

    func testSearchReplaceUsesPersistentEngineForControllerNavigation() async {
        let editor = createCodeEditorView()
        editor.text = """
        alpha
        beta
        alpha
        """

        var options = SearchOptions()
        options.highlightResults = false
        options.flashResult = false

        if #available(macOS 13.0, iOS 16.0, *) {
            let controller = EditorController()
            controller.attach(to: editor)

            let results = await controller.find("alpha", options: options)
            XCTAssertEqual(results.count, 2)
            XCTAssertEqual(controller.matchCount, 2)
            XCTAssertEqual(controller.currentMatchIndex, 0)

            let nextResult = controller.findNext()
            XCTAssertNotNil(nextResult)
            XCTAssertEqual(nextResult?.index, 1)
            XCTAssertEqual(controller.matchCount, 2)
            XCTAssertEqual(controller.currentMatchIndex, 1)
        }
    }

    func testSearchReplaceUsesUTF16RangesForMatches() async throws {
        let editor = createCodeEditorView()
        let text = "😀 target\nplain target"
        editor.text = text

        var options = SearchOptions()
        options.highlightResults = false
        options.flashResult = false

        let engine = SearchReplaceEngine()
        engine.attach(to: editor)

        let results = await engine.findAll(pattern: "target", options: options)
        XCTAssertEqual(results.map(\.matchedText), ["target", "target"])

        let expectedRanges = try [text.range(of: "target"), text.range(of: "target", options: .backwards)]
            .map { NSRange(try XCTUnwrap($0), in: text) }
            .sorted { $0.location < $1.location }
        XCTAssertEqual(results.map(\.range), expectedRanges)
    }

    func testSearchReplaceWholeWordSkipsEmbeddedMatches() async {
        let editor = createCodeEditorView()
        editor.text = "foo foobar barfoo foo_bar foo"

        var options = SearchOptions()
        options.wholeWord = true
        options.highlightResults = false
        options.flashResult = false

        let engine = SearchReplaceEngine()
        engine.attach(to: editor)

        let results = await engine.findAll(pattern: "foo", options: options)
        XCTAssertEqual(results.map(\.matchedText), ["foo", "foo"])
        XCTAssertEqual(results.map(\.range.location), [0, 26])
    }

    private func backgroundColor(at location: Int, in editor: CodeEditorView) -> PlatformColor? {
        let range = NSRange(location: location, length: 1)
        guard let attrs = editor.textKitBridge.attributedSubstring(in: range) else { return nil }
        return attrs.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? PlatformColor
    }

    func testCurrentMatchColorNilPreservesLegacyBehavior() async throws {
        let editor = createCodeEditorView()
        editor.text = "alpha beta alpha"

        var options = SearchOptions()
        options.flashResult = false
        XCTAssertNil(options.currentMatchColor)

        let engine = SearchReplaceEngine()
        engine.attach(to: editor)
        _ = await engine.findAll(pattern: "alpha", options: options)

        let text = editor.text ?? ""
        let firstLoc = NSRange(try XCTUnwrap(text.range(of: "alpha")), in: text).location
        let secondLoc = NSRange(try XCTUnwrap(text.range(of: "alpha", options: [.backwards])), in: text).location

        XCTAssertEqual(backgroundColor(at: firstLoc, in: editor), options.highlightColor)
        XCTAssertEqual(backgroundColor(at: secondLoc, in: editor), options.highlightColor)
    }

    func testSearchOptionsCurrentMatchColorPaintsTwoLayers() async throws {
        let editor = createCodeEditorView()
        editor.text = "alpha beta alpha"

        var options = SearchOptions()
        options.flashResult = false
        options.highlightColor = PlatformColor.yellow.withAlphaComponent(0.3)
        options.currentMatchColor = PlatformColor.systemBlue.withAlphaComponent(0.5)

        let engine = SearchReplaceEngine()
        engine.attach(to: editor)
        _ = await engine.findAll(pattern: "alpha", options: options)

        let text = editor.text ?? ""
        let firstLoc = NSRange(try XCTUnwrap(text.range(of: "alpha")), in: text).location
        let secondLoc = NSRange(try XCTUnwrap(text.range(of: "alpha", options: [.backwards])), in: text).location

        XCTAssertEqual(engine.currentSearchIndex, 0)
        XCTAssertEqual(backgroundColor(at: firstLoc, in: editor), options.currentMatchColor)
        XCTAssertEqual(backgroundColor(at: secondLoc, in: editor), options.highlightColor)
    }

    func testFindNextRepaintsPreviousCurrentToHighlightColor() async {
        let editor = createCodeEditorView()
        editor.text = "alpha beta alpha gamma alpha"

        var options = SearchOptions()
        options.flashResult = false
        options.highlightColor = PlatformColor.yellow.withAlphaComponent(0.3)
        options.currentMatchColor = PlatformColor.systemBlue.withAlphaComponent(0.5)

        let engine = SearchReplaceEngine()
        engine.attach(to: editor)
        _ = await engine.findAll(pattern: "alpha", options: options)
        XCTAssertEqual(engine.currentSearchIndex, 0)

        _ = engine.findNext(from: nil)
        XCTAssertEqual(engine.currentSearchIndex, 1)

        let firstRange = engine.currentSearchResults[0].range
        let secondRange = engine.currentSearchResults[1].range

        XCTAssertEqual(
            backgroundColor(at: firstRange.location, in: editor),
            options.highlightColor,
            "previous current should revert to highlightColor"
        )
        XCTAssertEqual(
            backgroundColor(at: secondRange.location, in: editor),
            options.currentMatchColor,
            "new current should adopt currentMatchColor"
        )
    }

    func testFlashRangeReappliesCurrentMatchColorOnCurrentMatch() async throws {
        let editor = createCodeEditorView()
        editor.text = "alpha beta alpha"

        var options = SearchOptions()
        options.flashResult = true
        options.highlightColor = PlatformColor.yellow.withAlphaComponent(0.3)
        options.currentMatchColor = PlatformColor.systemBlue.withAlphaComponent(0.5)

        let engine = SearchReplaceEngine()
        engine.attach(to: editor)
        _ = await engine.findAll(pattern: "alpha", options: options)
        XCTAssertEqual(engine.currentSearchIndex, 0)

        // Wait past the 300 ms flash window.
        try await Task.sleep(nanoseconds: 450_000_000)

        let firstRange = engine.currentSearchResults[0].range
        XCTAssertEqual(
            backgroundColor(at: firstRange.location, in: editor),
            options.currentMatchColor,
            "post-flash, the active match must return to currentMatchColor"
        )
    }

    func testReplaceCurrentAdvancesToNextMatch() async {
        let editor = createCodeEditorView()
        editor.text = "alpha beta alpha gamma alpha"

        var options = SearchOptions()
        options.flashResult = false

        let controller = EditorController()
        controller.attach(to: editor)
        _ = await controller.find("alpha", options: options)
        XCTAssertEqual(controller.matchCount, 3)
        XCTAssertEqual(controller.currentMatchIndex, 0)

        _ = controller.findNext()
        XCTAssertEqual(controller.currentMatchIndex, 1)

        let replaced = controller.replaceCurrent(with: "OMEGA")
        XCTAssertTrue(replaced)
        XCTAssertEqual(controller.matchCount, 2, "one match consumed")

        let resultText = editor.text ?? ""
        XCTAssertEqual(resultText, "alpha beta OMEGA gamma alpha")
    }

    func testReplaceCurrentNoOpWhenNoMatches() async {
        let editor = createCodeEditorView()
        editor.text = "no matches here"

        let controller = EditorController()
        controller.attach(to: editor)

        let replaced = controller.replaceCurrent(with: "anything")
        XCTAssertFalse(replaced)
        XCTAssertEqual(editor.text, "no matches here")
    }

    func testClearSearchAlsoClearsHighlights() async throws {
        let editor = createCodeEditorView()
        editor.text = "alpha beta alpha"

        var options = SearchOptions()
        options.flashResult = false

        let controller = EditorController()
        controller.attach(to: editor)
        _ = await controller.find("alpha", options: options)
        XCTAssertEqual(controller.matchCount, 2)

        let text = editor.text ?? ""
        let firstLoc = NSRange(try XCTUnwrap(text.range(of: "alpha")), in: text).location
        XCTAssertNotNil(backgroundColor(at: firstLoc, in: editor))

        controller.clearSearch()

        XCTAssertEqual(controller.matchCount, 0)
        XCTAssertEqual(controller.currentMatchIndex, -1)
        XCTAssertNil(
            backgroundColor(at: firstLoc, in: editor),
            "clearSearch must remove in-editor highlights"
        )
    }

    func testFindPreviousRepaintsCorrectly() async {
        let editor = createCodeEditorView()
        editor.text = "alpha beta alpha gamma alpha"

        var options = SearchOptions()
        options.flashResult = false
        options.highlightColor = PlatformColor.yellow.withAlphaComponent(0.3)
        options.currentMatchColor = PlatformColor.systemBlue.withAlphaComponent(0.5)

        let engine = SearchReplaceEngine()
        engine.attach(to: editor)
        _ = await engine.findAll(pattern: "alpha", options: options)
        _ = engine.findNext(from: nil)
        _ = engine.findNext(from: nil)
        XCTAssertEqual(engine.currentSearchIndex, 2)

        _ = engine.findPrevious(from: nil)
        XCTAssertEqual(engine.currentSearchIndex, 1)

        let secondRange = engine.currentSearchResults[1].range
        let thirdRange = engine.currentSearchResults[2].range

        XCTAssertEqual(backgroundColor(at: secondRange.location, in: editor), options.currentMatchColor)
        XCTAssertEqual(backgroundColor(at: thirdRange.location, in: editor), options.highlightColor)
    }

    func testCodeFoldingDetectsAndTogglesSwiftRegions() async throws {
        let editor = createCodeEditorView()
        editor.language = .swift
        editor.text = """
        struct Example {
            func message() -> String {
                let value = "Hello"
                return value
            }
        }
        """

        let engine = CodeFoldingEngine()
        engine.configuration.minimumLineCount = 1
        engine.configuration.hidesFoldedContent = false
        engine.attach(to: editor)
        engine.updateFoldableRegions()

        let region = try await waitForFoldableRegion(in: engine)
        XCTAssertEqual(engine.folds(in: region.range).first?.range, region.range)

        XCTAssertTrue(engine.fold(region))
        XCTAssertTrue(engine.foldedRegions.contains(region.id))
        XCTAssertEqual(engine.folds(in: region.range).first?.isCollapsed, true)
        XCTAssertFalse(engine.fold(region))

        XCTAssertTrue(engine.unfold(region))
        XCTAssertFalse(engine.foldedRegions.contains(region.id))
        XCTAssertEqual(engine.folds(in: region.range).first?.isCollapsed, false)

        editor.textEditEventHub.publish(TextEditEvent(
            editedRange: NSRange(location: 0, length: 0),
            changeInLength: 2,
            documentLength: TextRangeUtilities.utf16Length(of: editor.text ?? "") + 2,
            editedCharacters: true
        ))
        let shiftedFold = engine.folds(in: NSRange(location: 0, length: NSMaxRange(region.range) + 2))
            .first { $0.id == region.id.uuidString }
        XCTAssertEqual(shiftedFold?.range.location, region.range.location + 2)
    }

    func testNewLanguagesHaveFoldingProviders() {
        let registry = FoldingProviderRegistry()

        for language in [Language.csharp, .kotlin, .dart, .dockerfile, .toml, .lua] {
            XCTAssertTrue(registry.hasProvider(for: language), "\(language.name) should have a folding provider registration")
        }
    }

    func testNewLanguagesHaveSymbolProviders() {
        let navigator = SymbolNavigator()

        for language in [Language.csharp, .kotlin, .dart, .dockerfile, .toml, .lua] {
            XCTAssertTrue(navigator.hasProvider(for: language), "\(language.name) should have a symbol provider registration")
        }
    }

    func testSymbolProviderCatalogCoversEveryLanguage() {
        let catalog = SymbolProviderCatalog.default

        for language in Language.allCases {
            XCTAssertTrue(catalog.hasProvider(for: language), "\(language.name) should be registered in SymbolProviderCatalog")
        }
    }

    func testSymbolNavigatorCachesPreserveSearchBreadcrumbAndLookupBehavior() async throws {
        let editor = createCodeEditorView()
        editor.language = .swift
        editor.text = String(repeating: " ", count: 200)

        var catalog = SymbolProviderCatalog()
        catalog.registerProvider(StaticDocumentSymbolProvider(), for: .swift)

        let navigator = SymbolNavigator(providerCatalog: catalog)
        navigator.attach(to: editor)

        _ = try await waitForSymbols(in: navigator)

        let inner = try XCTUnwrap(navigator.symbol(at: 35))
        XCTAssertEqual(inner.name, "inner")
        XCTAssertEqual(navigator.symbol(withId: inner.id)?.name, "inner")
        XCTAssertEqual(navigator.searchSymbols(query: "inn").map(\.name), ["inner"])

        editor.selectedRange = NSRange(location: 35, length: 0)
        navigator.updateBreadcrumbs()
        XCTAssertEqual(navigator.currentBreadcrumbs.map { $0.symbol.name }, ["Outer", "inner"])
    }

    private func waitForFoldableRegion(in engine: CodeFoldingEngine) async throws -> FoldableRegion {
        for _ in 0..<20 {
            if let region = engine.foldableRegions.first {
                return region
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTFail("Expected at least one foldable region")
        throw CancellationError()
    }

    private func waitForSymbols(in navigator: SymbolNavigator) async throws -> [DocumentSymbol] {
        for _ in 0..<30 {
            if !navigator.symbols.isEmpty {
                return navigator.symbols
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTFail("Expected symbols to be detected")
        throw CancellationError()
    }
}

private struct StaticDocumentSymbolProvider: DocumentSymbolProvider {
    func detectSymbols(in _: String) async -> [DocumentSymbol] {
        [
            DocumentSymbol(
                name: "Outer",
                kind: .class,
                range: NSRange(location: 0, length: 120),
                selectionRange: NSRange(location: 0, length: 5)
            ),
            DocumentSymbol(
                name: "inner",
                kind: .method,
                range: NSRange(location: 20, length: 30),
                selectionRange: NSRange(location: 20, length: 5)
            )
        ]
    }
}
