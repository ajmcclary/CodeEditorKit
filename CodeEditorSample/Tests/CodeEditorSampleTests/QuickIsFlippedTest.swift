#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif
@testable import CodeEditorPlugin
import XCTest

/// Simple test to verify isFlipped behavior
final class QuickIsFlippedTest: XCTestCase {
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    @MainActor
    func testIsFlippedIssue() async {
        // Create CodeEditorView
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))

        // Test 1: Check if CodeEditorView reports isFlipped correctly
        CrossPlatformLogger.logger().debug("CodeEditorView isFlipped: \(textView.isFlipped)")
        XCTAssertTrue(textView.isFlipped, "CodeEditorView MUST be flipped for correct text rendering")

        // Test 2: CodeEditorView should handle flipped coordinates internally
        // NSTextView-based implementations don't expose contentView
        // Just verify the text view itself is properly flipped
        XCTAssertTrue(textView.isFlipped, "CodeEditorView handles flipped coordinates internally")

        // Test 3: Enable line numbers and verify platform-specific behavior
        textView.isLineNumbersEnabled = true
        textView.layoutSubtreeIfNeeded()

        // On macOS, line numbers are handled by NSRulerView in the container view,
        // not by GutterView in the text view itself
        let hasGutterView = textView.subviews.contains(where: { $0 is GutterView })
        let message = "On macOS, GutterView should NOT be created - line numbers are handled by NSRulerView"
        XCTAssertFalse(hasGutterView, message)

        // Test 4: Add text and check coordinate system
        textView.text = "Line 1\nLine 2\nLine 3"
        textView.layoutSubtreeIfNeeded()

        // Get layout manager
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else {
            XCTFail("No layout manager or text container available")
            return
        }

        // Force layout
        layoutManager.ensureLayout(forCharacterRange: NSRange(location: 0, length: textView.string.count))

        // Check line positions
        let string = textView.string as NSString
        let firstLineRange = string.lineRange(for: NSRange(location: 0, length: 0))
        let lastLineIndex = string.length > 0 ? string.length - 1 : 0
        let lastLineRange = string.lineRange(for: NSRange(location: lastLineIndex, length: 0))

        let firstLineGlyphRange = layoutManager.glyphRange(forCharacterRange: firstLineRange, actualCharacterRange: nil)
        let lastLineGlyphRange = layoutManager.glyphRange(forCharacterRange: lastLineRange, actualCharacterRange: nil)

        let firstLineRect = layoutManager.boundingRect(forGlyphRange: firstLineGlyphRange, in: textContainer)
        let lastLineRect = layoutManager.boundingRect(forGlyphRange: lastLineGlyphRange, in: textContainer)

        CrossPlatformLogger.logger().debug(
            "First line Y: \(firstLineRect.origin.y), Last line Y: \(lastLineRect.origin.y)"
        )

        // In flipped coordinates, Y increases downward
        if firstLineRange.location != lastLineRange.location {
            XCTAssertLessThan(
                firstLineRect.origin.y,
                lastLineRect.origin.y,
                "In flipped coordinates, first line should have smaller Y than last line"
            )
        }
    }
#endif
}
