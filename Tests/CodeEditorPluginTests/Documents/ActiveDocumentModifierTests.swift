import CodeEditorCommon
@testable import CodeEditorPlugin
@testable import CodeEditorView
import SwiftUI
import Testing

@MainActor
@Suite("ActiveDocument modifier")
struct ActiveDocumentModifierTests {
    @Test("resolveTextBinding uses manager binding when activeID is set")
    func resolveTextBindingUsesManagerWhenActive() {
        let document = EditorDocument(name: "x.swift", text: "from manager")
        let documents = EditorDocuments(documents: [document])
        let storedBinding: Binding<String> = .constant("from stored")

        let resolved = CodeEditor.resolveTextBinding(
            stored: storedBinding,
            manager: documents
        )

        #expect(resolved.wrappedValue == "from manager")
    }

    @Test("resolveTextBinding falls back to stored when manager is nil")
    func resolveTextBindingFallbackWhenManagerNil() {
        let storedBinding: Binding<String> = .constant("from stored")

        let resolved = CodeEditor.resolveTextBinding(
            stored: storedBinding,
            manager: nil
        )

        #expect(resolved.wrappedValue == "from stored")
    }

    @Test("resolveTextBinding falls back to stored when activeID is nil")
    func resolveTextBindingFallbackWhenActiveNil() {
        let documents = EditorDocuments()
        let storedBinding: Binding<String> = .constant("from stored")

        let resolved = CodeEditor.resolveTextBinding(
            stored: storedBinding,
            manager: documents
        )

        #expect(resolved.wrappedValue == "from stored")
    }

    @Test("resolveInteractionBinding uses manager binding when active")
    func resolveInteractionUsesManagerWhenActive() {
        let state = EditorInteractionState(
            cursorPositions: [EditorCursorPosition(line: 3, column: 7)]
        )
        let document = EditorDocument(name: "x.swift", interactionState: state)
        let documents = EditorDocuments(documents: [document])
        let storedBinding: Binding<EditorInteractionState> = .constant(EditorInteractionState())

        let resolved = CodeEditor.resolveInteractionBinding(
            stored: storedBinding,
            manager: documents
        )

        #expect(resolved.wrappedValue == state)
    }

    @Test("resolveInteractionBinding falls back to stored when manager nil")
    func resolveInteractionFallbackWhenManagerNil() {
        let state = EditorInteractionState(
            cursorPositions: [EditorCursorPosition(line: 1, column: 1)]
        )
        let storedBinding: Binding<EditorInteractionState> = .constant(state)

        let resolved = CodeEditor.resolveInteractionBinding(
            stored: storedBinding,
            manager: nil
        )

        #expect(resolved.wrappedValue == state)
    }

    @Test("CodeEditor() no-arg init compiles and constructs")
    func noArgInitConstructs() {
        _ = CodeEditor()
    }

    @Test(".activeDocument(in:) modifier chain compiles")
    func activeDocumentModifierChainCompiles() {
        let document = EditorDocument(name: "x.swift", text: "active")
        let documents = EditorDocuments(documents: [document])

        // Verify the modifier chain shape advertised in the doc comment.
        let view = CodeEditor()
            .activeDocument(in: documents)
            .codeLanguage(.swift)

        // Touch body to materialize env modifiers; if anything refuses
        // to type-check, this expression won't compile.
        _ = view
        #expect(documents.active?.text == "active")
    }
}
