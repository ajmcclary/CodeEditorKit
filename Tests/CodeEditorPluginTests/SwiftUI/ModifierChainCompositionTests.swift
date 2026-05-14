//
//  ModifierChainCompositionTests.swift
//  CodeEditorPluginTests
//
//  Regression net for the SwiftUI modifier return-type migration.
//  Each test below is a modifier chain that failed to compile before
//  the 2026-05-14 migration because a `some View`-typed modifier
//  appeared upstream of a `CodeEditor`-typed one. If any case here
//  fails to compile, the migration has regressed.
//
//  Spec: docs/superpowers/specs/2026-05-14-swiftui-modifier-return-types-design.md
//

@testable import CodeEditorPlugin
import SwiftUI
import XCTest

@available(macOS 13.0, iOS 16.0, *)
final class ModifierChainCompositionTests: XCTestCase {
    // MARK: - Chains that previously failed to compile

    @MainActor
    func testLanguageBeforeOnTextChange() {
        let text = Binding<String>.constant("")
        _ = CodeEditor(text: text)
            .codeLanguage(.swift)
            .onTextChange { _ in }
    }

    @MainActor
    func testFontSizeBeforeCodeCompletion() {
        let text = Binding<String>.constant("")
        _ = CodeEditor(text: text)
            .codeFontSize(14)
            .codeCompletion { _ in [] }
    }

    @MainActor
    func testPerformanceObserverBeforeEditorController() {
        let text = Binding<String>.constant("")
        let observation = PerformanceObservation()
        let controller = EditorController()
        _ = CodeEditor(text: text)
            .performanceObserver(observation)
            .editorController(controller)
    }

    @MainActor
    func testActiveDocumentBeforeOnSelectionChange() {
        let text = Binding<String>.constant("")
        let documents = EditorDocuments()
        _ = CodeEditor(text: text)
            .activeDocument(in: documents)
            .onSelectionChange { _ in }
    }

    @MainActor
    func testLineNumbersBeforeEditorInteractionState() {
        let text = Binding<String>.constant("")
        let interaction = Binding<EditorInteractionState>.constant(
            EditorInteractionState()
        )
        _ = CodeEditor(text: text)
            .lineNumbers(true)
            .editorInteractionState(interaction)
    }

    @MainActor
    func testMemoryMonitorBeforeOnTextChange() {
        let text = Binding<String>.constant("")
        let monitor = MemoryMonitor()
        _ = CodeEditor(text: text)
            .memoryMonitor(monitor)
            .onTextChange { _ in }
    }

    // MARK: - Inverse orders — regression coverage (compiled before too)

    @MainActor
    func testOnTextChangeBeforeLanguage() {
        let text = Binding<String>.constant("")
        _ = CodeEditor(text: text)
            .onTextChange { _ in }
            .codeLanguage(.swift)
    }

    @MainActor
    func testEditorControllerBeforeFontSize() {
        let text = Binding<String>.constant("")
        let controller = EditorController()
        _ = CodeEditor(text: text)
            .editorController(controller)
            .codeFontSize(14)
    }
}
