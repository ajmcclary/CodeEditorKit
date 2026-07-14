#if canImport(SwiftUI)
import CodeEditorHighlightingCore
import CodeEditorView
import SwiftUI

// MARK: - Highlight-provider environment key

@available(macOS 13.0, iOS 16.0, *)
private struct CodeEditorHighlightProviderKey: EnvironmentKey {
    static let defaultValue: (any HighlightRangeProviding)? = nil
}

@available(macOS 13.0, iOS 16.0, *)
extension EnvironmentValues {
    /// Host-injected primary highlight provider, populated by the
    /// `.codeEditorHighlightProvider(_:)` modifier and read by the
    /// representable's `updateContainer` to install it on the underlying view.
    var codeEditorHighlightProvider: (any HighlightRangeProviding)? {
        get { self[CodeEditorHighlightProviderKey.self] }
        set { self[CodeEditorHighlightProviderKey.self] = newValue }
    }
}

// MARK: - Modifier

@available(macOS 13.0, iOS 16.0, *)
extension View {
    /// Installs a value-oriented ``CodeEditorHighlightingCore/HighlightRangeProviding``
    /// as the editor's *primary* syntax-highlight source.
    ///
    /// This is the SwiftUI entry point for the external highlight seam — the
    /// declarative counterpart to
    /// ``CodeEditorView/setExternalHighlightProvider(_:)`` and
    /// ``EditorController/setExternalHighlightProvider(_:)``. The provider is
    /// installed on the underlying `CodeEditorView` when the representable
    /// updates; the view's identity guard means re-installing the same provider
    /// object on subsequent updates is a cheap no-op.
    ///
    /// ## Semantics
    ///
    /// The injected provider *replaces* the built-in regex / SwiftSyntax
    /// highlighter as the primary source. Like SwiftUI's other reference-typed
    /// editor modifiers, it only ever *installs* a non-nil provider — passing
    /// `nil` (or omitting the modifier) leaves whatever is already installed in
    /// place. To restore the built-in highlighter, call
    /// `setExternalHighlightProvider(nil)` through the view or an
    /// `EditorController`.
    ///
    /// The provider only paints once the range-store pipeline is enabled:
    ///
    /// ```swift
    /// CodeEditor(text: $code)
    ///     .codeEditorHighlightProvider(treeSitterProvider)
    /// // with a configuration that sets
    /// //   performance.usesRangeBasedHighlighting = true
    /// //   display.useRangeStoreHighlighting     = true
    /// ```
    ///
    /// - Parameter provider: The value provider to install.
    /// - Returns: A view that installs `provider` on the editor.
    public func codeEditorHighlightProvider(
        _ provider: any HighlightRangeProviding
    ) -> some View {
        environment(\.codeEditorHighlightProvider, provider)
    }
}
#endif
