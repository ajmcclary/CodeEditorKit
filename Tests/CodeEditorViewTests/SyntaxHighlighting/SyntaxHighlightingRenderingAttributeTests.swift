import CodeEditorPlatform
@testable import CodeEditorView
import XCTest

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Verifies that syntax highlighting writes go through
/// `NSTextLayoutManager.setRenderingAttributes(_:for:)` and do not mutate
/// the underlying `NSAttributedString`. Migration spec at
/// `docs/superpowers/specs/2026-05-14-textkit2-coercion-design.md`.
@MainActor
final class SyntaxHighlightingRenderingAttributeTests: XCTestCase {
    private func makeView() -> CodeEditorView {
        #if canImport(AppKit)
        let view = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        #else
        let view = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 200))
        #endif
        view.language = .swift
        view.text = "func main() { let x = 42 }"
        #if canImport(AppKit)
        view.layoutSubtreeIfNeeded()
        #else
        view.layoutIfNeeded()
        #endif
        return view
    }

    /// Drive the bridge directly so we have a deterministic write (the
    /// AsyncSyntaxHighlighter debounces and may not flush within a test
    /// runloop). Verifies that bridge.addAttributes funnels to
    /// setRenderingAttributes.
    func testBridgeAddAttributesAppliesRenderingAttributes() throws {
        let view = makeView()
        let bridge = view.textKitBridge
        let range = NSRange(location: 0, length: 4) // "func"
        let color: PlatformColor
        #if canImport(AppKit)
        color = .systemRed
        #else
        color = .red
        #endif
        bridge.addAttributes([.foregroundColor: color], range: range)

        let layoutManager = try XCTUnwrap(view.textLayoutManager)
        let contentManager = try XCTUnwrap(layoutManager.textContentManager)

        var sawRenderingAttribute = false
        layoutManager.enumerateRenderingAttributes(
            from: contentManager.documentRange.location,
            reverse: false
        ) { _, attrs, _ in
            if attrs[.foregroundColor] != nil {
                sawRenderingAttribute = true
                return false
            }
            return true
        }
        XCTAssertTrue(sawRenderingAttribute,
                      "Expected bridge.addAttributes to apply .foregroundColor as a rendering attribute")
    }

    /// The bridge's persistent attribute path is separate — writes via
    /// addAttributes must NOT mutate the underlying NSAttributedString.
    /// (The text storage may carry a default `.foregroundColor` from
    /// `setupDefaultTheme`, but that value must not equal the color we
    /// applied via rendering attributes.)
    func testBridgeAddAttributesDoesNotMutateAttributedString() throws {
        let view = makeView()
        let bridge = view.textKitBridge
        let range = NSRange(location: 0, length: 4)
        let renderingColor: PlatformColor
        #if canImport(AppKit)
        renderingColor = .systemRed
        #else
        renderingColor = .red
        #endif
        bridge.addAttributes([.foregroundColor: renderingColor], range: range)

        let storage = try XCTUnwrap(view.textContentStorage?.textStorage)
        let storageColor = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? PlatformColor
        XCTAssertNotEqual(
            storageColor,
            renderingColor,
            "Rendering attribute writes must not mutate the underlying NSAttributedString"
        )
    }
}
