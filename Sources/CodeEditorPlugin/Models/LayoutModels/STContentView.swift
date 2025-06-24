import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - STContentView

/// Content view that contains layout fragments
public class STContentView: NSView, @preconcurrency NSTextInputClient {
    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
    }

    /// Text views need a flipped coordinate system on macOS
    override public var isFlipped: Bool {
        true
    }

    /// Accept first responder for text input
    override public var acceptsFirstResponder: Bool {
        if let textView = superview?.superview as? STTextView {
            return textView.isEditable
        }
        return true
    }

    override public func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            needsDisplay = true
        }
        return result
    }

    // MARK: - Keyboard Events

    override public func keyDown(with event: NSEvent) {
        // Use input method system for proper text input
        interpretKeyEvents([event])
    }

    /// Handle mouse events for text selection
    override public func mouseDown(with event: NSEvent) {
        // Forward to parent STTextView
        if let textView = superview?.superview as? STTextView {
            textView.mouseDown(with: event)
        } else {
            super.mouseDown(with: event)
        }
    }

    override public func mouseDragged(with event: NSEvent) {
        if let textView = superview?.superview as? STTextView {
            textView.mouseDragged(with: event)
        } else {
            super.mouseDragged(with: event)
        }
    }

    override public func mouseUp(with event: NSEvent) {
        if let textView = superview?.superview as? STTextView {
            textView.mouseUp(with: event)
        } else {
            super.mouseUp(with: event)
        }
    }

    // MARK: - NSTextInputClient

    public func insertText(_ string: Any, replacementRange: NSRange) {
        // Forward to parent STTextView
        if let textView = superview?.superview as? STTextView {
            textView.insertText(string, replacementRange: replacementRange)
        }
    }

    public func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        // Forward to parent STTextView
        if let textView = superview?.superview as? STTextView {
            textView.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
        }
    }

    public func unmarkText() {
        // Forward to parent STTextView
        if let textView = superview?.superview as? STTextView {
            textView.unmarkText()
        }
    }

    public func selectedRange() -> NSRange {
        // Forward to parent STTextView
        if let textView = superview?.superview as? STTextView {
            return textView.selectedRange()
        }
        return NSRange(location: 0, length: 0)
    }

    public func markedRange() -> NSRange {
        // Forward to parent STTextView
        if let textView = superview?.superview as? STTextView {
            return textView.markedRange()
        }
        return NSRange(location: NSNotFound, length: 0)
    }

    public func hasMarkedText() -> Bool {
        // Forward to parent STTextView
        if let textView = superview?.superview as? STTextView {
            return textView.hasMarkedText()
        }
        return false
    }

    public func attributedSubstring(
        forProposedRange range: NSRange,
        actualRange: NSRangePointer?
    ) -> NSAttributedString? {
        // Forward to parent STTextView
        if let textView = superview?.superview as? STTextView {
            return textView.attributedSubstring(forProposedRange: range, actualRange: actualRange)
        }
        return nil
    }

    public func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        // Forward to parent STTextView
        if let textView = superview?.superview as? STTextView {
            return textView.validAttributesForMarkedText()
        }
        return []
    }

    public func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        // Forward to parent STTextView
        if let textView = superview?.superview as? STTextView {
            return textView.firstRect(forCharacterRange: range, actualRange: actualRange)
        }
        return NSRect.zero
    }

    public func characterIndex(for point: NSPoint) -> Int {
        // Forward to parent STTextView
        if let textView = superview?.superview as? STTextView {
            return textView.characterIndex(for: point)
        }
        return 0
    }

    override public func doCommand(by selector: Selector) {
        // Forward to parent STTextView or handle directly
        if let textView = superview?.superview as? STTextView {
            textView.doCommand(by: selector)
        }
    }

    deinit {
        // Cleanup if needed
    }
}
