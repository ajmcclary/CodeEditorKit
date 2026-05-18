import CodeEditorCommon
@testable import CodeEditorPlugin
import Foundation
import Testing

#if canImport(SwiftUI)
@preconcurrency import SwiftUI

@Suite("EditorInteractionState binding surface")
struct EditorInteractionStateBindingTests {
    // Removed `defaultBinding` and `modifierSetsBinding` (2026-05-14):
    // pre-migration the interaction-state binding was a stored property on
    // the CodeEditor struct; these tests inspected it directly. Post-migration
    // (see docs/superpowers/specs/2026-05-14-swiftui-modifier-return-types-design.md)
    // the binding lives in the internal `codeEditorIntent` env value and
    // .editorInteractionState(_:) returns `some View`. Equivalent coverage:
    //   - CodeEditorIntentTests.testDefaultIntentHasAllFieldsNil
    //     (intent.interactionState defaults nil → body falls back to constant)
    //   - ModifierChainCompositionTests.testLineNumbersBeforeEditorInteractionState
    //     (modifier exists and the chain compiles)
    //   - The two coordinator-level tests below (`coordinatorWritesCursorPosition`
    //     and `coordinatorAppliesExternalCursorPosition`) cover the end-to-end
    //     behavior with a real binding.

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
        #if canImport(AppKit)
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
