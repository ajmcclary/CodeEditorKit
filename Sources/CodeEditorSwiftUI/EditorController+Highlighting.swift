import CodeEditorHighlightingCore
#if canImport(SwiftUI)
import CodeEditorView
import Foundation

@available(macOS 13.0, iOS 16.0, *)
extension EditorController {
    /// Inject a value-oriented ``CodeEditorHighlightingCore/HighlightRangeProviding``
    /// as the editor's *primary* syntax-highlight source.
    ///
    /// This is the `EditorController` façade over
    /// ``CodeEditorView/setExternalHighlightProvider(_:)``. The provider is
    /// remembered by the controller and re-applied automatically whenever the
    /// controller (re)attaches to a `CodeEditorView` — so it works even when
    /// called before the SwiftUI representable has created the underlying view
    /// (unlike the transient find/fold commands, which are no-ops while
    /// unattached).
    ///
    /// ## Semantics
    ///
    /// The injected provider *replaces* the built-in regex / SwiftSyntax
    /// highlighter as the primary source (it does not augment it). Passing `nil`
    /// restores the built-in highlighter. See
    /// ``CodeEditorView/setExternalHighlightProvider(_:)`` for the full
    /// contract, including the `usesRangeBasedHighlighting` /
    /// `useRangeStoreHighlighting` configuration flags the pipeline requires.
    ///
    /// ## Example
    ///
    /// ```swift
    /// @State private var controller = EditorController()
    ///
    /// var body: some View {
    ///     CodeEditor(text: $code)
    ///         .editorController(controller)
    ///         .onAppear {
    ///             if let provider = try? TreeSitterHighlightProvider.standard(languageID: .swift) {
    ///                 controller.setExternalHighlightProvider(provider)
    ///             }
    ///         }
    /// }
    /// ```
    ///
    /// - Parameter provider: The value provider to install, or `nil` to restore
    ///   the built-in highlighter.
    public func setExternalHighlightProvider(_ provider: (any HighlightRangeProviding)?) {
        storedExternalHighlightProvider = provider
        codeEditorView?.setExternalHighlightProvider(provider)
    }

    /// The value provider currently remembered by this controller, or `nil`
    /// when the editor uses its built-in highlighter.
    public var externalHighlightProvider: (any HighlightRangeProviding)? {
        storedExternalHighlightProvider
    }
}
#endif
