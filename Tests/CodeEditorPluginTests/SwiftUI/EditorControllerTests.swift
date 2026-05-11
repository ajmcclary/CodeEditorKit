@testable import CodeEditorPlugin
import Foundation
import Testing

#if canImport(SwiftUI)
@preconcurrency import SwiftUI

@Suite("EditorController surface")
struct EditorControllerTests {
    @Test("unattached controller reports isAttached false")
    @MainActor
    func unattachedReportsFalse() {
        let controller = EditorController()
        #expect(!controller.isAttached)
        #expect(controller.symbols.isEmpty)
        #expect(controller.matchCount == 0)
        #expect(controller.currentMatchIndex == -1)
        #expect(controller.currentLineNumber == nil)
    }

    @Test("unattached controller methods are safe no-ops")
    @MainActor
    func unattachedNoOps() {
        let controller = EditorController()
        // None of these should crash or mutate state when no view is attached.
        controller.foldAll()
        controller.unfoldAll()
        controller.fold(atLine: 1)
        controller.unfold(atLine: 1)
        controller.toggleFold(atLine: 1)
        controller.gotoLine(1)
        controller.refreshSymbols()
        controller.removeAllAnnotations()
        controller.reloadAnnotations()
        controller.clearAnnotationsDataSource()
        controller.clearSearch()
        #expect(!controller.isAttached)
    }

    @Test("clearSearch resets match counters")
    @MainActor
    func clearSearchResets() {
        let controller = EditorController()
        controller.clearSearch()
        #expect(controller.matchCount == 0)
        #expect(controller.currentMatchIndex == -1)
    }

    @Test("editorController modifier stores controller on CodeEditor")
    @MainActor
    func modifierStoresController() {
        let controller = EditorController()
        let editor = CodeEditor(text: .constant("hello"))
        let modified = editor.editorController(controller)
        #expect(modified.editorController === controller)
    }

    @Test("attach(to: nil) leaves controller detached")
    @MainActor
    func attachNilDetaches() {
        let controller = EditorController()
        // Synthesize a detach without ever attaching — should be safe.
        controller.attach(to: nil)
        #expect(!controller.isAttached)
        #expect(controller.symbols.isEmpty)
    }

    @Test("attaching to a CodeEditorView flips isAttached to true")
    @MainActor
    func attachingFlipsState() {
        let controller = EditorController()
        let view = CodeEditorView(frame: .zero)
        controller.attach(to: view)
        #expect(controller.isAttached)
        controller.attach(to: nil)
        #expect(!controller.isAttached)
    }

    @Test("find with empty pattern returns no results without crashing")
    @MainActor
    func findEmptyPatternIsNoOp() async {
        let controller = EditorController()
        let view = CodeEditorView(frame: .zero)
        controller.attach(to: view)
        let results = await controller.find("")
        #expect(results.isEmpty)
        #expect(controller.matchCount == 0)
        #expect(controller.currentMatchIndex == -1)
    }
}
#endif
