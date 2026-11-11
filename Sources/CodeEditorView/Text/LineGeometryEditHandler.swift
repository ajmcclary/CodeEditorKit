import CodeEditorTextModel
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

        guard let textView,
              let textStorage = textView.textContentStorage?.textStorage else {
            // Fall back to full rebuild if text view is unavailable.
            textView?.rebuildLineGeometryStoreFromCurrentTextStorage()
            return
        }

        // Edit events are delivered a runloop hop after the edit. If the
        // store was rebuilt from the text storage in between (the text
        // setters do this), it already contains this edit, and applying the
        // event as an incremental change would count the edited lines twice.
        if let generation = textView.publishingTextChangeGeneration,
           generation <= textView.lineGeometrySyncedGeneration {
            return
        }

        // swiftlint:disable:next legacy_objc_type
        let text = textStorage.string as NSString
        guard let update = incrementalUpdate(for: event, in: text) else {
            textView.rebuildLineGeometryStoreFromCurrentTextStorage()
            return
        }
        geometryStore.removeLines(in: update.lines)
        geometryStore.insertLines(update.replacement, at: update.lines.lowerBound)
    }

    // MARK: - Incremental Update

    /// The store lines an edit invalidates and the lines that replace them.
    private struct IncrementalUpdate {
        /// Pre-edit line indices to remove.
        let lines: ClosedRange<Int>

        /// Post-edit lines to insert at `lines.lowerBound`.
        let replacement: [LineGeometry]
    }

    /// Works out which store lines `event` replaces and what replaces them,
    /// or returns `nil` when the event cannot be applied to the store as it
    /// stands and the store must be rebuilt instead.
    ///
    /// The affected lines run from the line holding the edit's location to
    /// the line holding the first character after the replaced range; that
    /// second line is included because an edit that removes a line
    /// terminator joins it to what precedes it. Everything before the first
    /// affected line is untouched by the edit, and everything after the last
    /// is only shifted, so the replacement is exactly the lines of the new
    /// text between the start of the first affected line and the shifted end
    /// of the last one.
    ///
    /// - Parameter text: The text storage's content after the edit.
    private func incrementalUpdate(
        for event: TextEditEvent,
        in text: NSString // swiftlint:disable:this legacy_objc_type
    ) -> IncrementalUpdate? {
        let lineCount = geometryStore.lineCount
        let oldLength = geometryStore.totalUtf16Length
        let location = event.editedRange.location
        let replacedEnd = location + event.editedRange.length

        // The store must describe the text as it was just before this edit,
        // and the text must be as this edit left it. Neither holds when the
        // store was reset, or when several edits were made before their
        // events were delivered: `text` then already contains the later
        // edits, and this event's offsets no longer line up with it. The
        // rebuild the caller falls back to reads all of them at once, and
        // marks their events as already applied.
        guard lineCount > 0,
              location >= 0,
              event.editedRange.length >= 0,
              replacedEnd <= oldLength,
              event.editedRange.length + event.changeInLength >= 0,
              oldLength + event.changeInLength == text.length
        else {
            return nil
        }

        let firstLine = geometryStore.lineIndex(forUtf16Offset: location)
        let lastLine = geometryStore.lineIndex(forUtf16Offset: replacedEnd)
        let reachesDocumentEnd = lastLine == lineCount - 1
        let regionStart = geometryStore.utf16Offset(forLineIndex: firstLine)
        let oldRegionEnd = reachesDocumentEnd
            ? oldLength
            : geometryStore.utf16Offset(forLineIndex: lastLine + 1)
        let regionEnd = oldRegionEnd + event.changeInLength

        var replacement: [LineGeometry] = []
        var position = regionStart
        while position < regionEnd {
            var lineStart = 0
            var lineEnd = 0
            var contentsEnd = 0
            text.getLineStart(
                &lineStart,
                end: &lineEnd,
                contentsEnd: &contentsEnd,
                for: NSRange(location: position, length: 0)
            )
            // The region must start and end on line boundaries of the new
            // text. It does not when the edit joins a CR to an LF across the
            // region's edge, making one terminator out of two lines' worth.
            guard lineStart == position, lineEnd <= regionEnd else {
                return nil
            }
            replacement.append(LineGeometry(
                utf16Length: lineEnd - lineStart,
                lineEndingLength: lineEnd - contentsEnd,
                estimatedHeight: estimatedHeight(forLineAt: firstLine + replacement.count)
            ))
            position = lineEnd
        }

        // A document always ends with a line, empty when the text is empty
        // or ends with a line terminator.
        if reachesDocumentEnd, replacement.last.map({ $0.lineEndingLength > 0 }) ?? true {
            replacement.append(LineGeometry(
                utf16Length: 0,
                lineEndingLength: 0,
                estimatedHeight: estimatedHeight(forLineAt: firstLine + replacement.count)
            ))
        }

        return IncrementalUpdate(lines: firstLine...lastLine, replacement: replacement)
    }

    /// The estimated height a replacement line inherits from the pre-edit
    /// line at the same index.
    private func estimatedHeight(forLineAt lineIndex: Int) -> CGFloat {
        geometryStore.lineGeometry(at: lineIndex)?.estimatedHeight ?? geometryStore.defaultEstimatedHeight
    }

    // MARK: - Lifecycle

    /// Detach from the text view's event hub. Call before the text view
    /// is deallocated to break the observer reference.
    func detach() {
        textView?.textEditEventHub.removeObserver(self)
        textView = nil
    }
}
