import CodeEditorView
import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Shared Parameter Assembly

/// Shared parameter-bag assembly for the AppKit and UIKit
/// `CodeEditorRepresentable` types. Each platform file defines a struct with
/// the same stored property names; this extension resolves against whichever
/// of the two is in scope so the verbose initializer calls live in one place.
@available(macOS 13.0, iOS 16.0, *)
extension CodeEditorRepresentable {
    /// Bag of values handed to `CodeEditorRepresentableHelper.createAndSetupContainer`
    /// from `makeNSView` / `makeUIView`.
    var containerParameters: CodeEditorRepresentableHelper.ContainerParameters {
        CodeEditorRepresentableHelper.ContainerParameters(
            text: text,
            language: language,
            theme: theme,
            configuration: configuration,
            runtimeDependencies: runtimeDependencies,
            interactionState: interactionState,
            editorController: editorController,
            hostEditorState: hostEditorState,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange,
            swiftUICompletionProvider: swiftUICompletionProvider
        )
    }

    /// Bag of values handed to `CodeEditorRepresentableHelper.updateContainer`
    /// from `updateNSView` / `updateUIView`. Takes the environment because it
    /// is only available inside the protocol callback.
    func updateParameters(environment: EnvironmentValues) -> CodeEditorRepresentableHelper.UpdateParameters {
        CodeEditorRepresentableHelper.UpdateParameters(
            text: text,
            language: language,
            theme: theme,
            configuration: configuration,
            runtimeDependencies: runtimeDependencies,
            interactionState: interactionState,
            editorController: editorController,
            hostEditorState: hostEditorState,
            environment: environment,
            swiftUICompletionProvider: swiftUICompletionProvider
        )
    }
}
