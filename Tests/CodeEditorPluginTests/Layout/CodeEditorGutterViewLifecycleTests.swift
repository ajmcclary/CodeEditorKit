#if canImport(AppKit)
import AppKit
@testable import CodeEditorTheming
@testable import CodeEditorView
import XCTest

@MainActor
final class LineNumberRulerViewLifecycleTests: XCTestCase {
    func testRulerInitializesWithScrollViewDocumentView() throws {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let textView = CodeEditorView(frame: .zero)
        scrollView.documentView = textView

        let ruler = LineNumberRulerView(scrollView: scrollView, orientation: .verticalRuler)

        XCTAssertIdentical(ruler.textView, textView)
        XCTAssertIdentical(ruler.clientView, textView)
    }

    func testSelectionDidChangeUpdatesActiveLine() throws {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        scrollView.documentView = textView
        textView.string = "alpha\nbeta\ngamma"

        let ruler = LineNumberRulerView(scrollView: scrollView, orientation: .verticalRuler)

        textView.setSelectedRange(NSRange(location: 0, length: 0))
        ruler.selectionDidChange()
        XCTAssertEqual(ruler.lastActiveLineNumber, 1)

        textView.setSelectedRange(NSRange(location: 7, length: 0)) // inside "beta"
        ruler.selectionDidChange()
        XCTAssertEqual(ruler.lastActiveLineNumber, 2)
    }

    func testApplyThemeForwardsToRenderer() throws {
        let ruler = LineNumberRulerView(scrollView: nil, orientation: .verticalRuler)
        let beforeColor = ruler.renderer.themedLineNumberColor

        ruler.apply(theme: .lcarsDark)

        XCTAssertNotEqual(beforeColor.cgColor, ruler.renderer.themedLineNumberColor.cgColor)
    }

    func testTextContainerInsetRoundtripsWithRulerToggle() throws {
        let container = CodeEditorContainerView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))

        // Disable line numbers so we observe the bare baseline first.
        var configWithout = container.configuration
        configWithout.display.isLineNumbersEnabled = false
        container.configuration = configWithout
        let disabledInset = container.baseTextContainerInsetWidth
        XCTAssertNil(container.macLineNumberRulerView)
        XCTAssertEqual(container.textView.textContainerInset.width, disabledInset, accuracy: 0.5)

        // Toggle on — the ruler occupies the gutter slot, so text inset
        // should include only normal editor padding, not the ruler width.
        container.showsLineNumbers = true
        let enabledInset = container.configuration.layout.lineNumberPadding
        XCTAssertNotNil(container.macLineNumberRulerView)
        XCTAssertEqual(container.textView.textContainerInset.width, enabledInset, accuracy: 0.5)

        // Toggle off — inset should return to the reduced disabled padding.
        container.showsLineNumbers = false
        XCTAssertNil(container.macLineNumberRulerView)
        XCTAssertEqual(container.textView.textContainerInset.width, disabledInset, accuracy: 0.5)
    }

    func testRulerThicknessFollowsConfigurationChange() throws {
        let container = CodeEditorContainerView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        var config = container.configuration
        config.display.isLineNumbersEnabled = true
        config.layout.gutterWidth = 72

        container.configuration = config

        let ruler = try XCTUnwrap(container.macLineNumberRulerView)
        XCTAssertEqual(ruler.ruleThickness, 72, accuracy: 0.5)
    }
}
#endif
