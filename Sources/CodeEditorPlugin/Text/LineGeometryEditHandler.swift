import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - LineGeometryEditHandler

/// Observes `TextEditEventHub` and keeps `LineGeometryStore` in sync with
/// `NSTextStorage` after text edits using incremental node-level updates
/// (O(m log n) for m affected lines).
///
/// Attribute-only edits (e.g., syntax highlighting color changes) are
/// no-ops — they don't affect line geometry.
@MainActor
internal final class LineGeometryEditHandler: TextEditEventObserving {
    /// The geometry store to keep in sync.
    private let geometryStore: LineGeometryStore

    /// Weak reference to the text view for accessing `textStorage`.
    private weak var textView: CodeEditorView?

    // MARK: - Initialization

    init(geometryStore: LineGeometryStore, textView: CodeEditorView) {
        self.geometryStore = geometryStore
        self.textView = textView
        textView.textEditEventHub.addObserver(self)
    }

    // MARK: - TextEditEventObserving

    func textStorageDidApplyEdit(_ event: TextEditEvent) {
        guard event.editedCharacters else {
            // Attribute-only change — geometry is unaffected.
            return
        }

        guard let textView, let textStorage = textView.textStorage else {
            // Fall back to full rebuild if text view is unavailable.
            textView?.rebuildLineGeometryStoreFromCurrentTextStorage()
            return
        }

        // Compute the affected line range from the edit.
        let oldLineStart = geometryStore.lineIndex(forUtf16Offset: event.editedRange.location)
        let oldLineEnd = geometryStore.lineIndex(
            forUtf16Offset: max(0, event.editedRange.location + event.editedRange.length - 1)
        )

        // Build new geometries for the affected region from the text storage.
        // swiftlint:disable:next legacy_objc_type
        let nsString = textStorage.string as NSString
        let length = nsString.length

        // Enumerate lines in the affected region.
        var newGeometries: [LineGeometry] = []
        var lineIndex = oldLineStart
        var searchPos = geometryStore.utf16Offset(forLineIndex: lineIndex)
        searchPos = max(0, searchPos - 1) // Start from previous line start

        // Find the actual start of the line at oldLineStart
        if searchPos > 0 {
            var lineStart = 0
            var lineEnd = 0
            var contentsEnd = 0
            nsString.getLineStart(
                &lineStart,
                end: &lineEnd,
                contentsEnd: &contentsEnd,
                for: NSRange(location: searchPos, length: 0)
            )
            searchPos = lineStart
        }

        // Determine how many lines to scan: the affected line count plus
        // new lines introduced or removed.
        let oldAffectedCount = oldLineEnd - oldLineStart + 1
        let newEndOffset = event.editedRange.location + event.editedRange.length + event.changeInLength
        let newLineEnd = geometryStore.lineIndex(forUtf16Offset: max(0, newEndOffset - 1))
        let scanToLine = max(newLineEnd, oldLineEnd) + 1 // one extra for safety

        // Enumerate lines starting from searchPos
        var pos = searchPos
        while pos < length {
            var lineStart = 0
            var lineEnd = 0
            var contentsEnd = 0
            nsString.getLineStart(
                &lineStart,
                end: &lineEnd,
                contentsEnd: &contentsEnd,
                for: NSRange(location: pos, length: 0)
            )
            let utf16Length = lineEnd - lineStart
            let lineEndingLength = lineEnd - contentsEnd

            newGeometries.append(LineGeometry(
                utf16Length: utf16Length,
                lineEndingLength: lineEndingLength,
                estimatedHeight: geometryStore.lineGeometry(at: lineIndex)?.estimatedHeight ?? 17.0
            ))

            lineIndex += 1
            pos = lineEnd
            if lineIndex > scanToLine || pos >= length { break }

            // If we've scanned past the edit region and hit the next old
            // line that already exists, we can stop.
            if lineIndex > oldLineEnd && pos >= newEndOffset {
                break
            }
        }

        // Apply the incremental edit.
        if oldAffectedCount > 0 {
            // First remove the old lines, then insert the new ones
            geometryStore.removeLines(in: oldLineStart...oldLineEnd)
        }

        if !newGeometries.isEmpty {
            geometryStore.insertLines(newGeometries, at: oldLineStart)
        }
    }

    // MARK: - Lifecycle

    /// Detach from the text view's event hub. Call before the text view
    /// is deallocated to break the observer reference.
    func detach() {
        textView?.textEditEventHub.removeObserver(self)
        textView = nil
    }
}
