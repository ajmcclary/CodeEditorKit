import CodeEditorCommon
import CodeEditorConfiguration
import CodeEditorDiagnostics
import CodeEditorHighlightingCore
import CodeEditorLanguages
import CodeEditorPlatform
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import DesignKitThemes
import Foundation
import SwiftUI
import XCTest

/// Value-oriented provider with no editor-view reference, standing in for an
/// external tree-sitter adapter.
@MainActor
private final class StubValueProvider: HighlightRangeProviding {
    func prepare(for _: HighlightDocumentSnapshot) async {}
    func invalidate(
        for _: HighlightTextEdit,
        in document: HighlightDocumentSnapshot
    ) async -> HighlightInvalidation {
        .everything(length: document.utf16Length)
    }
    func highlights(
        in _: HighlightRange,
        of _: HighlightDocumentSnapshot
    ) async throws -> [HighlightToken] { [] }
}

@available(macOS 13.0, iOS 16.0, *)
final class ExternalHighlightProviderSeamTests: XCTestCase {
    // MARK: - EditorController seam

    @MainActor
    func testControllerForwardsProviderToAttachedView() {
        let controller = EditorController()
        let view = CodeEditorView()
        controller.attach(to: view)

        let provider = StubValueProvider()
        controller.setExternalHighlightProvider(provider)

        XCTAssertIdentical(controller.externalHighlightProvider, provider)
        XCTAssertIdentical(view.externalHighlightProvider, provider)
    }

    @MainActor
    func testControllerReAppliesProviderSetBeforeAttach() {
        let controller = EditorController()
        let provider = StubValueProvider()

        // Set before any view exists — the controller remembers it.
        controller.setExternalHighlightProvider(provider)
        XCTAssertIdentical(controller.externalHighlightProvider, provider)

        // On attach, the remembered provider is installed onto the new view.
        let view = CodeEditorView()
        controller.attach(to: view)
        XCTAssertIdentical(view.externalHighlightProvider, provider)
    }

    @MainActor
    func testControllerClearsProviderOnAttachedView() {
        let controller = EditorController()
        let view = CodeEditorView()
        controller.attach(to: view)

        let provider = StubValueProvider()
        controller.setExternalHighlightProvider(provider)
        XCTAssertIdentical(view.externalHighlightProvider, provider)

        controller.setExternalHighlightProvider(nil)
        XCTAssertNil(controller.externalHighlightProvider)
        XCTAssertNil(view.externalHighlightProvider)
    }

    // MARK: - SwiftUI modifier smoke test

    @MainActor
    func testModifierInstallsProviderThroughRepresentableUpdate() {
        let coordinator = CodeEditorCoordinator(
            text: .constant("let value = 1"),
            onTextChange: nil,
            onSelectionChange: nil
        )
        let container = CodeEditorContainerView()
        let runtimeDependencies = EditorRuntimeDependencies(memoryMonitor: MemoryMonitor())

        coordinator.setupContainer(
            container,
            text: "let value = 1",
            language: .swift,
            theme: .default,
            configuration: .default,
            runtimeDependencies: runtimeDependencies,
            onTextChange: nil,
            onSelectionChange: nil
        )
        XCTAssertNil(container.textView.externalHighlightProvider)

        // Environment carries the provider exactly as
        // `.codeEditorHighlightProvider(_:)` would set it.
        let provider = StubValueProvider()
        var environment = EnvironmentValues()
        environment.codeEditorHighlightProvider = provider

        CodeEditorRepresentableHelper.updateContainer(
            container,
            parameters: CodeEditorRepresentableHelper.UpdateParameters(
                text: "let value = 1",
                language: .swift,
                theme: .default,
                configuration: .default,
                runtimeDependencies: runtimeDependencies,
                interactionState: .constant(EditorInteractionState()),
                editorController: nil,
                hostEditorState: EditorState(),
                environment: environment,
                swiftUICompletionProvider: nil
            ),
            coordinator: coordinator
        )

        XCTAssertIdentical(container.textView.externalHighlightProvider, provider)
    }

    @MainActor
    func testModifierReturnsView() {
        let editor = CodeEditor(text: .constant("test"))
            .codeEditorHighlightProvider(StubValueProvider())
        let typeName = String(reflecting: type(of: editor))
        XCTAssertTrue(typeName.contains("EnvironmentKeyWritingModifier") || typeName.contains("ModifiedContent"))
    }
}
