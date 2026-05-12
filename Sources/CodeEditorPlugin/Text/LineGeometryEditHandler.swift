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

        // Compute the affected pre-edit line range from the edit.
        let preEditLineCount = geometryStore.lineCount

        // The incremental algorithm assumes at least one line exists in the
        // store. If the store was reset (memory pressure, transient nil
        // textStorage during setup) but the text view now has content, fall
        // back to a full rebuild instead of computing offsets against an
        // empty tree.
        guard preEditLineCount > 0 else {
            textView.rebuildLineGeometryStoreFromCurrentTextStorage()
            return
        }
        let oldLineStart = geometryStore.lineIndex(forUtf16Offset: event.editedRange.location)
        let oldLineEnd = geometryStore.lineIndex(
            forUtf16Offset: max(0, event.editedRange.location + event.editedRange.length - 1)
        )
        var removalEnd = oldLineEnd
        if event.editedRange.length > 0, removalEnd + 1 < preEditLineCount {
            let nextLineStart = geometryStore.utf16Offset(forLineIndex: removalEnd + 1)
            if event.editedRange.location + event.editedRange.length >= nextLineStart {
                removalEnd += 1
            }
        }

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

        let oldAffectedCount = removalEnd - oldLineStart + 1
        let scanEnd: Int
        if removalEnd + 1 < preEditLineCount {
            let oldBoundary = geometryStore.utf16Offset(forLineIndex: removalEnd + 1)
            scanEnd = min(length, max(searchPos, oldBoundary + event.changeInLength))
        } else {
            scanEnd = length
        }

        // Enumerate replacement lines in the post-edit text. The scan end is
        // the shifted start offset of the first unaffected old line, so lines
        // outside the affected region stay in the tree.
        var pos = searchPos
        while pos < length, pos < scanEnd {
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
            if pos >= length { break }
        }
        if length == 0 {
            newGeometries.append(LineGeometry(
                utf16Length: 0,
                lineEndingLength: 0,
                estimatedHeight: geometryStore.lineGeometry(at: oldLineStart)?.estimatedHeight ?? 17.0
            ))
        } else if scanEnd == length, newGeometries.last?.lineEndingLength ?? 0 > 0 {
            newGeometries.append(LineGeometry(
                utf16Length: 0,
                lineEndingLength: 0,
                estimatedHeight: geometryStore.lineGeometry(at: oldLineStart)?.estimatedHeight ?? 17.0
            ))
        }

        // Apply the incremental edit.
        if oldAffectedCount > 0 {
            // First remove the old lines, then insert the new ones
            geometryStore.removeLines(in: oldLineStart...removalEnd)
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
