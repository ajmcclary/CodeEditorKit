import CodeEditorCommon
import CodeEditorLanguages
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import SwiftUI
import Testing

@MainActor
@Suite("EditorInteractionSynchronizer")
struct EditorInteractionSynchronizerTests {
    @Test("host swap resets baseline and user edit marks dirty")
    func dirtyStateLifecycle() {
        let state = EditorState()
        let synchronizer = EditorInteractionSynchronizer(hostState: state)

        synchronizer.installBaseline("one")
        synchronizer.receiveText("two", language: .swift)
        #expect(state.isDirty)

        synchronizer.markClean(currentText: "two")
        #expect(state.isDirty == false)
    }

    @Test("selection mirrors into host and interaction cursor state")
    func selectionMirroring() {
        let hostState = EditorState()
        var interactionState = EditorInteractionState()
        let binding = Binding(
            get: { interactionState },
            set: { interactionState = $0 }
        )
        let synchronizer = EditorInteractionSynchronizer(
            hostState: hostState,
            interactionState: binding
        )

        synchronizer.receiveSelection(
            NSRange(location: 3, length: 0),
            text: "a\nbc"
        )

        #expect(hostState.selection == SelectionState(line: 2, column: 2))
        #expect(interactionState.cursorPositions == [
            EditorCursorPosition(line: 2, column: 2)
        ])
    }

    @Test("stored cursor restores with UTF-16 offsets")
    func cursorRestoration() {
        var interactionState = EditorInteractionState(
            cursorPositions: [EditorCursorPosition(line: 2, column: 2)]
        )
        let synchronizer = EditorInteractionSynchronizer(
            interactionState: Binding(
                get: { interactionState },
                set: { interactionState = $0 }
            )
        )
        let view = CodeEditorView(frame: .zero)
        #if canImport(AppKit)
        view.string = "😀\nbc"
        #else
        view.text = "😀\nbc"
        #endif

        synchronizer.applyInteractionState(to: view)

        #expect(view.selectedRange == NSRange(location: 4, length: 0))
    }
}
