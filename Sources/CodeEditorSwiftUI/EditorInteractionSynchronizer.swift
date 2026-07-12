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

        guard var state = interactionState?.wrappedValue else { return }
        let cursor = EditorCursorPosition(
            line: selection.line,
            column: selection.column
        )
        guard state.cursorPositions != [cursor] else { return }
        state.cursorPositions = [cursor]
        interactionState?.wrappedValue = state
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

    func applyInteractionState(to textView: CodeEditorView) {
        guard let cursor = interactionState?.wrappedValue.cursorPositions?.first else {
            return
        }

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

    private static func utf16Offset(
        for cursor: EditorCursorPosition,
        in text: String
    ) -> Int {
        let targetLine = max(1, cursor.line)
        let targetColumn = max(1, cursor.column)
        var line = 1
        var column = 1
        var offset = 0

        for character in text {
            if line == targetLine, column == targetColumn {
                return offset
            }

            if character == "\n" {
                if line == targetLine {
                    return offset
                }
                line += 1
                column = 1
            } else {
                column += 1
            }

            offset += String(character).utf16.count
        }

        return TextRangeUtilities.utf16Length(of: text)
    }
}
