import CodeEditorCommon
import CodeEditorLanguages
import CodeEditorTextModel
import CodeEditorView
import Foundation
import SwiftUI

/// Synchronizes dirty, selection, and cursor state between an editor and host.
@MainActor
final class EditorInteractionSynchronizer {
    weak var hostState: EditorState?
    var interactionState: Binding<EditorInteractionState>?

    private var dirtyTracker = DirtyTracker()

    /// The bound cursor as it read the last time the editor looked at the
    /// binding (after writing to it, or after applying it). The bound cursor
    /// is pushed into the view only when the host changed it since then, so
    /// the editor's own echo never moves the caret or collapses a selection.
    private var lastObservedCursor: EditorCursorPosition?
    private var hasObservedCursor = false

    init(
        hostState: EditorState? = nil,
        interactionState: Binding<EditorInteractionState>? = nil
    ) {
        self.hostState = hostState
        self.interactionState = interactionState
    }

    func installBaseline(_ text: String) {
        dirtyTracker.setBaseline(text)
        if let hostState, hostState.isDirty {
            hostState.isDirty = false
        }
    }

    func receiveText(_ text: String, language: Language) {
        guard let hostState else { return }

        if hostState.language != language {
            hostState.language = language
        }
        let lineCount = EditorStateBridge.lineCount(of: text)
        if hostState.lineCount != lineCount {
            hostState.lineCount = lineCount
        }
        let isDirty = dirtyTracker.isDirty(currentText: text)
        if hostState.isDirty != isDirty {
            hostState.isDirty = isDirty
        }
    }

    func receiveSelection(_ range: NSRange, text: String) {
        guard hostState != nil || interactionState != nil else { return }

        let selection = EditorStateBridge.deriveSelection(from: range, in: text)
        if let hostState, hostState.selection != selection {
            hostState.selection = selection
        }

        guard let interactionState else { return }
        var state = interactionState.wrappedValue
        let cursor = EditorCursorPosition(
            line: selection.line,
            column: selection.column
        )
        if state.cursorPositions != [cursor] {
            state.cursorPositions = [cursor]
            interactionState.wrappedValue = state
        }
        // Re-read: a binding that ignores writes (`.constant`) keeps its own
        // value, and that value is then what "unchanged by the host" means.
        observeBoundCursor(interactionState.wrappedValue.cursorPositions?.first)
    }

    func markClean(currentText: String) {
        dirtyTracker.markClean(currentText: currentText)
        if let hostState, hostState.isDirty {
            hostState.isDirty = false
        }
    }

    func setHardwareAccelerationActive(_ isActive: Bool) {
        guard let hostState,
              hostState.hardwareAccelerationActive != isActive else { return }
        hostState.hardwareAccelerationActive = isActive
    }

    /// Pushes the bound cursor into the view, but only when the host changed
    /// it since the editor last wrote or applied it.
    func applyInteractionState(to textView: CodeEditorView) {
        guard let interactionState else { return }
        let boundCursor = interactionState.wrappedValue.cursorPositions?.first
        if hasObservedCursor, boundCursor == lastObservedCursor { return }
        observeBoundCursor(boundCursor)
        guard let cursor = boundCursor else { return }

        #if canImport(AppKit)
        let text = textView.string
        #else
        let text = textView.text ?? ""
        #endif
        let targetRange = NSRange(
            location: Self.utf16Offset(for: cursor, in: text),
            length: 0
        )
        guard textView.selectedRange != targetRange else { return }
        textView.setSelectedRangeWithoutScrolling(targetRange)
    }

    private func observeBoundCursor(_ cursor: EditorCursorPosition?) {
        lastObservedCursor = cursor
        hasObservedCursor = true
    }

    /// Resolves a 1-based line/column to a UTF-16 offset with the same line
    /// semantics `EditorStateBridge.deriveSelection` uses to produce it: a
    /// line ends at each `\n` UTF-16 unit (so CRLF documents count lines
    /// too), and the column counts `Character`s from the line start. A column
    /// past the line's end resolves to the line's end, before any `\r\n`.
    static func utf16Offset(
        for cursor: EditorCursorPosition,
        in text: String
    ) -> Int {
        // swiftlint:disable:next legacy_objc_type
        let nsText = text as NSString
        let length = nsText.length
        let targetLine = max(1, cursor.line)
        let targetColumn = max(1, cursor.column)

        var lineStart = 0
        var line = 1
        while line < targetLine {
            let newline = nsText.range(
                of: "\n",
                options: .literal,
                range: NSRange(location: lineStart, length: length - lineStart)
            )
            guard newline.location != NSNotFound else { return length }
            lineStart = newline.location + 1
            line += 1
        }

        let newline = nsText.range(
            of: "\n",
            options: .literal,
            range: NSRange(location: lineStart, length: length - lineStart)
        )
        var lineEnd = newline.location == NSNotFound ? length : newline.location
        if newline.location != NSNotFound, lineEnd > lineStart,
           nsText.character(at: lineEnd - 1) == 0x0D {
            lineEnd -= 1
        }

        let lineText = nsText.substring(
            with: NSRange(location: lineStart, length: lineEnd - lineStart)
        )
        var offset = lineStart
        var column = 1
        for character in lineText {
            if column == targetColumn { return offset }
            offset += character.utf16.count
            column += 1
        }
        return offset
    }
}
