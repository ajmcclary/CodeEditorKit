@testable import CodeEditorPlugin
import Foundation
import Testing

#if canImport(SwiftUI)
@preconcurrency import SwiftUI

@Suite("EditorInteractionState binding surface")
struct EditorInteractionStateBindingTests {
    @Test("CodeEditor with no interaction state binding uses constant default")
    func defaultBinding() {
        let editor = CodeEditor(text: .constant("hello"))
        // The internal binding exists and is a constant
        let state = editor.interactionState.wrappedValue
        #expect(state.cursorPositions == nil)
    }

    @Test("editorInteractionState modifier sets custom binding")
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
}
#endif
