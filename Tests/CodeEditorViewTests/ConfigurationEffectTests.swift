#if canImport(AppKit)
import AppKit
import CodeEditorAnnotations
import CodeEditorConfiguration
import CodeEditorTextModel
@testable import CodeEditorView
import XCTest

/// Each configuration value here used to be stored, encoded and shown in
/// host settings without the editor reading it. These tests pin the effect
/// each one now has, so a value cannot go back to being decoration.
@MainActor
final class ConfigurationEffectTests: XCTestCase {
    private func makeView(_ text: String = "", width: CGFloat = 400) -> CodeEditorView {
        let view = CodeEditorView(frame: CGRect(x: 0, y: 0, width: width, height: 300))
        view.string = text
        return view
    }

    private func configure(_ view: CodeEditorView, _ change: (inout EditorConfiguration) -> Void) {
        var configuration = view.configuration
        change(&configuration)
        view.configuration = configuration
    }

    private func type(_ text: String, in view: CodeEditorView) {
        view.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    // MARK: - Auto close

    func testTypingAnOpeningBracketInsertsItsCloser() {
        let view = makeView()
        type("(", in: view)
        XCTAssertEqual(view.string, "()")
        XCTAssertEqual(view.selectedRange().location, 1)
    }

    func testTypingTheCloserStepsOverIt() {
        let view = makeView()
        type("[", in: view)
        type("]", in: view)
        XCTAssertEqual(view.string, "[]")
        XCTAssertEqual(view.selectedRange().location, 2)
    }

    func testAutoCloseBracketsOffInsertsOnlyWhatWasTyped() {
        let view = makeView()
        configure(view) { $0.behavior.autoCloseBrackets = false }
        type("{", in: view)
        XCTAssertEqual(view.string, "{")
    }

    func testTypingAQuoteInsertsItsPair() {
        let view = makeView()
        type("\"", in: view)
        XCTAssertEqual(view.string, "\"\"")
        XCTAssertEqual(view.selectedRange().location, 1)
    }

    func testAutoCloseQuotesOffInsertsOnlyWhatWasTyped() {
        let view = makeView()
        configure(view) { $0.behavior.autoCloseQuotes = false }
        type("\"", in: view)
        XCTAssertEqual(view.string, "\"")
    }

    func testAnApostropheInsideAWordIsNotPaired() {
        let view = makeView("don")
        view.setSelectedRange(NSRange(location: 3, length: 0))
        type("'", in: view)
        XCTAssertEqual(view.string, "don'")
    }

    func testTypingABracketOverASelectionWrapsIt() {
        let view = makeView("value")
        view.setSelectedRange(NSRange(location: 0, length: 5))
        type("(", in: view)
        XCTAssertEqual(view.string, "(value)")
        XCTAssertEqual(view.selectedRange().location, 6)
    }

    func testABracketBeforeAWordIsNotClosed() {
        let view = makeView("value")
        view.setSelectedRange(NSRange(location: 0, length: 0))
        type("(", in: view)
        XCTAssertEqual(view.string, "(value")
    }

    func testAutoCloseIsOneUndoStep() throws {
        let view = makeView()
        view.allowsUndo = true
        // A text view only has an undo manager in a window.
        let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        window.contentView = view
        defer { window.close() }

        type("(", in: view)
        XCTAssertEqual(view.string, "()")
        let undoManager = try XCTUnwrap(view.undoManager)
        undoManager.undo()
        XCTAssertEqual(view.string, "")
    }

    func testAReadOnlyEditorIsLeftAlone() {
        let view = makeView("value")
        configure(view) { $0.behavior.isEditable = false }
        view.setSelectedRange(NSRange(location: 5, length: 0))
        type("(", in: view)
        XCTAssertEqual(view.string, "value")
        XCTAssertEqual(view.selectedRange().location, 5)
    }

    // MARK: - Auto indent

    func testReturnKeepsTheLineIndentation() {
        let view = makeView("    let x = 1")
        view.setSelectedRange(NSRange(location: 13, length: 0))
        view.insertNewline(nil)
        XCTAssertEqual(view.string, "    let x = 1\n    ")
    }

    func testReturnAfterAnOpeningBraceIndentsOneLevel() {
        let view = makeView("func f() {")
        view.setSelectedRange(NSRange(location: 10, length: 0))
        view.insertNewline(nil)
        XCTAssertEqual(view.string, "func f() {\n    ")
    }

    func testReturnBetweenBracesOpensTheBlock() {
        let view = makeView("  if x {}")
        view.setSelectedRange(NSRange(location: 8, length: 0))
        view.insertNewline(nil)
        XCTAssertEqual(view.string, "  if x {\n      \n  }")
        XCTAssertEqual(view.selectedRange().location, 15)
    }

    func testIndentUsesTabsWhenSpacesAreOff() {
        let view = makeView("f {")
        configure(view) { $0.layout.insertSpacesForTabs = false }
        view.setSelectedRange(NSRange(location: 3, length: 0))
        view.insertNewline(nil)
        XCTAssertEqual(view.string, "f {\n\t")
    }

    func testAutoIndentOffInsertsABareNewline() {
        let view = makeView("    let x = 1")
        configure(view) { $0.behavior.isAutoIndentEnabled = false }
        view.setSelectedRange(NSRange(location: 13, length: 0))
        view.insertNewline(nil)
        XCTAssertEqual(view.string, "    let x = 1\n")
    }

    // MARK: - Character spacing

    func testCharacterSpacingKernsTheTextAndWhatIsTypedNext() throws {
        let view = makeView("hello")
        configure(view) { $0.layout.characterSpacing = 2 }
        let storage = try XCTUnwrap(view.textContentStorage?.textStorage)
        XCTAssertEqual(storage.attribute(.kern, at: 0, effectiveRange: nil) as? CGFloat, 2)
        XCTAssertEqual(view.typingAttributes[.kern] as? CGFloat, 2)

        configure(view) { $0.layout.characterSpacing = 0 }
        XCTAssertNil(storage.attribute(.kern, at: 0, effectiveRange: nil))
        XCTAssertNil(view.typingAttributes[.kern])
    }

    func testCharacterSpacingSurvivesReplacingTheText() throws {
        let view = makeView("hello")
        configure(view) { $0.layout.characterSpacing = 2 }
        view.string = "replaced"
        let storage = try XCTUnwrap(view.textContentStorage?.textStorage)
        XCTAssertEqual(storage.attribute(.kern, at: 0, effectiveRange: nil) as? CGFloat, 2)

        view.string = ""
        type("x", in: view)
        XCTAssertEqual(storage.attribute(.kern, at: 0, effectiveRange: nil) as? CGFloat, 2)
    }

    func testCharacterSpacingWidensTheLine() throws {
        let view = makeView("hello world")
        let before = try lineWidth(in: view)
        configure(view) { $0.layout.characterSpacing = 3 }
        XCTAssertGreaterThan(try lineWidth(in: view), before + 20)
    }

    private func lineWidth(in view: CodeEditorView) throws -> CGFloat {
        let layoutManager = try XCTUnwrap(view.textLayoutManager)
        layoutManager.ensureLayout(for: layoutManager.documentRange)
        var width: CGFloat = 0
        layoutManager.enumerateTextLayoutFragments(from: layoutManager.documentRange.location) { fragment in
            for line in fragment.textLineFragments { width = max(width, line.typographicBounds.width) }
            return true
        }
        return width
    }

    // MARK: - Wrap width fraction

    func testWrapWidthFractionNarrowsTheWrappingWidth() throws {
        let view = makeView("text", width: 400)
        configure(view) { $0.layout.wrapLines = true }
        let container = try XCTUnwrap(view.textContainer)
        let fullWidth = 400 - view.textContainerInset.width * 2
        XCTAssertTrue(container.widthTracksTextView)

        configure(view) { $0.layout.textContainerWidthFraction = 0.5 }
        XCTAssertFalse(container.widthTracksTextView)
        XCTAssertEqual(container.containerSize.width, (fullWidth * 0.5).rounded(.down), accuracy: 0.5)

        // A container that does not track the view follows it by hand.
        view.setFrameSize(NSSize(width: 600, height: 300))
        let resizedFullWidth = 600 - view.textContainerInset.width * 2
        XCTAssertEqual(container.containerSize.width, (resizedFullWidth * 0.5).rounded(.down), accuracy: 0.5)

        configure(view) { $0.layout.textContainerWidthFraction = 1 }
        XCTAssertTrue(container.widthTracksTextView)
    }

    func testWrapWidthFractionAppliesInsideTheContainerView() throws {
        for minimap in [false, true] {
            let container = CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 600, height: 400))
            var configuration = container.configuration
            configuration.layout.wrapLines = true
            configuration.layout.textContainerWidthFraction = 0.5
            configuration.display.isMinimapVisible = minimap
            container.configuration = configuration
            container.layoutSubtreeIfNeeded()

            let textView = container.textView
            let textContainer = try XCTUnwrap(textView.textContainer)
            let viewWidth = try XCTUnwrap(textView.enclosingScrollView).contentView.bounds.width
            let fullWidth = viewWidth - textView.textContainerInset.width * 2
            XCTAssertFalse(textContainer.widthTracksTextView, "minimap: \(minimap)")
            XCTAssertEqual(
                textContainer.containerSize.width,
                (fullWidth * 0.5).rounded(.down),
                accuracy: 0.5,
                "minimap: \(minimap)"
            )
        }
    }

    func testWrapWidthFractionIsIgnoredWithoutWrapping() throws {
        let view = makeView("text", width: 400)
        configure(view) {
            $0.layout.wrapLines = false
            $0.layout.textContainerWidthFraction = 0.5
        }
        let container = try XCTUnwrap(view.textContainer)
        XCTAssertEqual(container.containerSize.width, CGFloat.greatestFiniteMagnitude)
    }

    // MARK: - Link detection and inline predictions

    func testLinkDetectionFollowsTheConfiguration() throws {
        let view = makeView("see https://example.com")
        XCTAssertFalse(view.isAutomaticLinkDetectionEnabled)

        configure(view) { $0.behavior.isAutomaticLinkDetectionEnabled = true }
        XCTAssertTrue(view.isAutomaticLinkDetectionEnabled)

        // Turning it off removes the links already in the text.
        let storage = try XCTUnwrap(view.textContentStorage?.textStorage)
        storage.addAttribute(.link, value: "https://example.com", range: NSRange(location: 4, length: 19))
        configure(view) { $0.behavior.isAutomaticLinkDetectionEnabled = false }
        XCTAssertFalse(view.isAutomaticLinkDetectionEnabled)
        XCTAssertNil(storage.attribute(.link, at: 4, effectiveRange: nil))
    }

    func testEnablingLinkDetectionMarksLinksAlreadyInTheText() throws {
        let view = makeView("see https://example.com for more")
        configure(view) { $0.behavior.isAutomaticLinkDetectionEnabled = true }
        let storage = try XCTUnwrap(view.textContentStorage?.textStorage)

        // Detection runs asynchronously.
        let deadline = Date().addingTimeInterval(arrivalTimeout)
        while storage.attribute(.link, at: 6, effectiveRange: nil) == nil, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertNotNil(storage.attribute(.link, at: 6, effectiveRange: nil))
        XCTAssertEqual(view.string, "see https://example.com for more")
    }

    func testInlinePredictionsFollowTheConfiguration() {
        let view = makeView()
        configure(view) { $0.behavior.showInlineCompletionSuggestions = false }
        XCTAssertEqual(view.inlinePredictionType, .no)
        configure(view) { $0.behavior.showInlineCompletionSuggestions = true }
        XCTAssertEqual(view.inlinePredictionType, .default)
    }

    // MARK: - Completion trigger characters

    func testTheDefaultTriggerCharactersMeanTheLanguagesOwn() {
        let view = makeView()
        view.language = .swift
        let swiftCharacters = view.featureDependencies.syntaxHighlightingService.completionTriggerCharacters(for: .swift)
        XCTAssertEqual(view.completionTriggerCharacters, swiftCharacters)
        XCTAssertNotEqual(swiftCharacters, EditorConfiguration.Behavior.defaultCompletionTriggerCharacters)
    }

    func testConfiguredTriggerCharactersReplaceTheLanguagesOwn() {
        let view = makeView()
        view.language = .swift
        configure(view) { $0.behavior.completionTriggerCharacters = ["."] }
        XCTAssertEqual(view.completionTriggerCharacters, ["."])

        // A language change keeps the configured set.
        view.language = .python
        XCTAssertEqual(view.completionTriggerCharacters, ["."])
    }

    // MARK: - Invisible characters

    func testInvisibleCharactersAreDrawnByTheEditorsOwnFragments() throws {
        let view = makeView("a b\tc\n")
        let layoutManager = try XCTUnwrap(view.textLayoutManager)
        XCTAssertNil(layoutManager.delegate)

        configure(view) { $0.display.areInvisibleCharactersVisible = true }
        XCTAssertIdentical(layoutManager.delegate, view)
        layoutManager.ensureLayout(for: layoutManager.documentRange)
        var fragments: [NSTextLayoutFragment] = []
        layoutManager.enumerateTextLayoutFragments(from: layoutManager.documentRange.location) { fragment in
            fragments.append(fragment)
            return true
        }
        let marked = try XCTUnwrap(fragments.first as? TextLayoutFragment)
        XCTAssertTrue(marked.isInvisibleCharactersEnabled)
        XCTAssertFalse(marked.centersLinesVertically)

        configure(view) { $0.display.areInvisibleCharactersVisible = false }
        XCTAssertNil(layoutManager.delegate)
    }

    func testInvisibleCharacterMarksAreDrawn() throws {
        let view = makeView("a b c d e f")
        view.layoutSubtreeIfNeeded()
        let plain = try inkedPixelCount(of: view)
        configure(view) { $0.display.areInvisibleCharactersVisible = true }
        view.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(try inkedPixelCount(of: view), plain)
    }

    /// How many pixels differ from the view's background.
    private func inkedPixelCount(of view: CodeEditorView) throws -> Int {
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let background = try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide - 1, y: bitmap.pixelsHigh - 1))
        var count = 0
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide where bitmap.colorAt(x: x, y: y) != background {
                count += 1
            }
        }
        return count
    }

    // MARK: - Annotations

    func testAnnotationsOffHidesThemWithoutDiscardingThem() {
        let view = makeView("first line\nsecond line")
        let dataSource = TestAnnotationDataSource()
        view.annotationsDataSource = dataSource
        view.addAnnotation(Annotation(range: NSRange(location: 0, length: 5), content: "note", kind: .warning))
        view.reloadAnnotations()
        XCTAssertEqual(view.annotationViews.count, 1)

        configure(view) { $0.display.areAnnotationsEnabled = false }
        view.reloadAnnotations()
        XCTAssertTrue(view.annotationViews.isEmpty)
        XCTAssertEqual(view.allAnnotations.count, 1)

        configure(view) { $0.display.areAnnotationsEnabled = true }
        view.reloadAnnotations()
        XCTAssertEqual(view.annotationViews.count, 1)
    }
}
#endif
