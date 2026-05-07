@testable import CodeEditorPlugin
import Foundation
import Testing

#if canImport(SwiftUI)
@preconcurrency import SwiftUI

@Suite("EditorInteractionState binding surface")
struct EditorInteractionStateBindingTests {
    @Test("CodeEditor with no interaction state binding uses constant default")
    @MainActor
    func defaultBinding() {
        let editor = CodeEditor(text: .constant("hello"))
        // The internal binding exists and is a constant
        let state = editor.interactionState.wrappedValue
        #expect(state.cursorPositions == nil)
    }

    @Test("editorInteractionState modifier sets custom binding")
    @MainActor
    func modifierSetsBinding() {
        let editor = CodeEditor(text: .constant("hello"))
        let customBinding = Binding<EditorInteractionState>(
            get: { EditorInteractionState(cursorPositions: [EditorCursorPosition(line: 1, column: 1)]) },
            set: { _ in }
        )
        let modified = editor.editorInteractionState(customBinding)
        #expect(modified.interactionState.wrappedValue.cursorPositions?.first?.line == 1)
    }

    @Test("EditorInteractionState is Sendable")
    func sendableConformance() {
        let state = EditorInteractionState(
            cursorPositions: [EditorCursorPosition(line: 1, column: 1)]
        )
        let copy = state
        #expect(copy == state)
    }

    @Test("coordinator writes cursor position into interaction binding")
    @MainActor
    func coordinatorWritesCursorPosition() {
        var state = EditorInteractionState()
        let binding = Binding<EditorInteractionState>(
            get: { state },
            set: { state = $0 }
        )
        let coordinator = CodeEditorCoordinator(
            text: .constant("a\nbc"),
            onTextChange: nil,
            onSelectionChange: nil
        )
        coordinator.updateInteractionStateBinding(binding)
        coordinator.currentText = "a\nbc"

        coordinator.handleSelectionChange(NSRange(location: 3, length: 0))

        #expect(state.cursorPositions == [EditorCursorPosition(line: 2, column: 2)])
    }

    @Test("coordinator applies external cursor position writes")
    @MainActor
    func coordinatorAppliesExternalCursorPosition() {
        var state = EditorInteractionState(
            cursorPositions: [EditorCursorPosition(line: 2, column: 2)]
        )
        let binding = Binding<EditorInteractionState>(
            get: { state },
            set: { state = $0 }
        )
        let coordinator = CodeEditorCoordinator(
            text: .constant("a\nbc"),
            onTextChange: nil,
            onSelectionChange: nil
        )
        coordinator.updateInteractionStateBinding(binding)
        let textView = CodeEditorView()
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        textView.string = "a\nbc"
        #else
        textView.text = "a\nbc"
        #endif

        coordinator.applyInteractionState(to: textView)

        #expect(textView.selectedRange.location == 3)

        state.cursorPositions = [EditorCursorPosition(line: 1, column: 1)]
        coordinator.applyInteractionState(to: textView)
        #expect(textView.selectedRange.location == 0)
    }
}
#endif
