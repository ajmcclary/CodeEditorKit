import CodeEditorConfiguration
@testable import CodeEditorView
import XCTest

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif


/// Verifies that `CodeEditorView` initialization produces a TextKit 2
/// stack. Apple's `NSTextView` / `UITextView` automatically stand up a
/// TK2 network in `super.init(frame:)`. Reading the legacy `textStorage`
/// property during setup triggers a TK1 compatibility shim and clears
/// `textLayoutManager`. These tests are the canary for that regression
/// class.
///
/// Related: docs/superpowers/specs/2026-05-14-textkit2-coercion-design.md
@MainActor
final class CodeEditorViewTextKit2InitTests: CleanupTestCase {
    func testInitFrameProducesTK2Stack() {
        let view = createCodeEditorView(frame: .zero)
        XCTAssertNotNil(view.textLayoutManager,
                        "CodeEditorView(frame:) must initialize with a TextKit 2 layout manager")
        XCTAssertNotNil(view.textContentStorage,
                        "CodeEditorView(frame:) must initialize with a TextKit 2 content storage")
        XCTAssertNotNil(view.textLayoutManager?.textContentManager,
                        "TextKit 2 content manager must be wired to the layout manager")
    }

    /// Verifies the TK2 stack survives a syntax-highlighting trigger
    /// (configuration change). The previous regression bound to TK1
    /// reproduced on configuration didSet, so this exercises the same path
    /// the canary regression depended on.
    func testTK2StackSurvivesConfigurationChange() {
        let view = createCodeEditorView(frame: .zero)
        XCTAssertNotNil(view.textLayoutManager)
        var config = view.configuration
        config.display.fontSize += 1
        view.configuration = config
        XCTAssertNotNil(view.textLayoutManager,
                        "TextKit 2 stack must survive a configuration change")
    }

    #if canImport(AppKit)
    func testTK2StackSurvivesWrappedLayoutConfigurationChange() {
        let view = createCodeEditorView(frame: NSRect(x: 0, y: 0, width: 320, height: 240))
        view.string = String(repeating: "This is a long markdown paragraph that wraps in the editor.\n", count: 3)
        XCTAssertNotNil(view.textLayoutManager)

        var config = view.configuration
        config.layout.wrapLines = true
        view.configuration = config

        XCTAssertNotNil(view.textLayoutManager,
                        "TextKit 2 stack must survive enabling wrapped layout")
    }

    /// Round-trips through the public `attributedContent` setter and getter.
    /// Both paths must avoid `NSTextView.textStorage`, which would coerce the
    /// view to TextKit 1.
    func testAttributedContentRoundTripPreservesTK2Stack() {
        let view = createCodeEditorView(frame: .zero)
        XCTAssertNotNil(view.textLayoutManager)

        let replacement = NSAttributedString(string: "let answer = 42\n")
        view.attributedContent = replacement
        XCTAssertNotNil(view.textLayoutManager,
                        "Setting attributedContent must not coerce the view to TextKit 1")
        XCTAssertNotNil(view.textContentStorage,
                        "TextKit 2 content storage must survive attributedContent setter")

        let readback = view.attributedContent
        XCTAssertEqual(readback?.string, replacement.string)
        XCTAssertNotNil(view.textLayoutManager,
                        "Reading attributedContent must not coerce the view to TextKit 1")
    }
    #endif
}
