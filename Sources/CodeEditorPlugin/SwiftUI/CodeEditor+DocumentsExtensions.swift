#if canImport(SwiftUI)
import SwiftUI

@available(macOS 13.0, iOS 16.0, *)
extension View {
    /// Wires the active `EditorDocument`'s text, language, and
    /// interaction state into the `CodeEditor` below this modifier.
    ///
    /// When `documents.activeID` is non-nil, the modifier:
    /// - Installs `documents` into the SwiftUI environment under
    ///   `\.activeDocumentManager`; `CodeEditor.body` reads it and
    ///   overrides its text and interaction-state bindings with the
    ///   manager's per-active-id bindings.
    /// - Applies `.codeLanguage(documents.active?.language ?? .plainText)`
    ///   so syntax highlighting follows the active document.
    ///
    /// When `documents.activeID` is nil, the modifier still installs
    /// the manager (so a later activation re-renders correctly) and
    /// sets the language to `.plainText`. Hosts that want a richer
    /// empty-state UI should render it separately.
    ///
    /// Switching `documents.activeID` hot-swaps the bindings to the
    /// new document; previously-active document state is preserved in
    /// the manager's storage.
    ///
    /// Defined on `View` (rather than `CodeEditor`) so it composes with
    /// view-typed modifiers higher in the chain. As of 2026-05-14 every
    /// public CodeEditor modifier returns `some View`, so call order is
    /// no longer constrained.
    ///
    /// ## Example
    ///
    /// ```swift
    /// CodeEditor()
    ///     .editorController(controller)
    ///     .activeDocument(in: documents)
    ///     .lineNumbers(true)
    ///     .codeWorkspaceRoot(workspaceRoot)
    /// ```
    ///
    /// - Parameter documents: The active-document collection to wire.
    /// - Returns: A view with the manager installed and the active
    ///   document's language applied.
    public func activeDocument(in documents: EditorDocuments) -> some View {
        environment(\.activeDocumentManager, documents)
            .codeLanguage(documents.active?.language ?? .plainText)
    }
}

#endif
