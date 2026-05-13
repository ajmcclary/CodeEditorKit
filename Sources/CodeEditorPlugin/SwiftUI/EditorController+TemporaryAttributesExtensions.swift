#if canImport(AppKit) && canImport(SwiftUI)
import AppKit
import SwiftUI

@available(macOS 13.0, iOS 16.0, *)
extension EditorController {
    /// Apply presentation-only attributes to a character range. Attributes
    /// are layered on top of syntax highlighting and survive NSTextStorage
    /// edits — attribute ranges adjust as text changes.
    ///
    /// Intended for transient decorations such as LSP diagnostic underlines,
    /// search-match highlights, or debug-stop indicators. Not for syntax
    /// highlighting — register a `HighlightingStrategy` for that.
    ///
    /// No-op when no `CodeEditorView` is attached.
    public func applyTemporaryAttributes(
        _ attributes: [NSAttributedString.Key: Any],
        to range: NSRange
    ) {
        temporaryAttributesStore?.apply(attributes, to: range)
    }

    /// Remove every temporary-attribute key applied via this controller that
    /// overlaps `range`.
    public func clearTemporaryAttributes(in range: NSRange) {
        temporaryAttributesStore?.clear(in: range)
    }

    /// Remove every temporary-attribute key applied via this controller.
    public func clearAllTemporaryAttributes() {
        temporaryAttributesStore?.clearAll()
    }

    /// UTF-16 length of the currently-attached document, or zero when the
    /// controller is unattached. Useful for clamping ranges before calling
    /// `applyTemporaryAttributes(_:to:)` against the active buffer.
    public var currentDocumentLength: Int {
        codeEditorView?.textStorage?.length ?? 0
    }
}
#endif
