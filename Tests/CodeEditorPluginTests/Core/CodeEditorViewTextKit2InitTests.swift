import XCTest

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@testable import CodeEditorPlugin

/// Verifies that `CodeEditorView` initialization produces a TextKit 2
/// stack. Apple's `NSTextView` / `UITextView` automatically stand up a
/// TK2 network in `super.init(frame:)`. Reading the legacy `textStorage`
/// property during setup triggers a TK1 compatibility shim and clears
/// `textLayoutManager`. These tests are the canary for that regression
/// class.
///
/// Related: docs/superpowers/specs/2026-05-14-textkit2-coercion-design.md
@MainActor
final class CodeEditorViewTextKit2InitTests: XCTestCase {
    func testInitFrameProducesTK2Stack() {
        let view = CodeEditorView(frame: .zero)
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
        let view = CodeEditorView(frame: .zero)
        XCTAssertNotNil(view.textLayoutManager)
        var config = view.configuration
        config.display.fontSize += 1
        view.configuration = config
        XCTAssertNotNil(view.textLayoutManager,
                        "TextKit 2 stack must survive a configuration change")
    }
}
