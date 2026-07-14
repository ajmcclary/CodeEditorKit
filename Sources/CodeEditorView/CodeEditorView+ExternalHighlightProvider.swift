import CodeEditorHighlightingCore
import Foundation

extension CodeEditorView {
    /// Injects a value-oriented ``CodeEditorHighlightingCore/HighlightRangeProviding``
    /// as the editor's *primary* syntax-highlight source.
    ///
    /// This is the public injection seam for external highlight engines — for
    /// example the tree-sitter-backed `TreeSitterHighlightProvider` shipped by
    /// the separate `CodeEditorTreeSitter` package. The provider is bridged onto
    /// the editor's internal range-store pipeline (via
    /// `SnapshotHighlightProviderBridge`), so conformers never see the editor
    /// view or the internal `RangeHighlightProviding` protocol; they trade only
    /// in the `Sendable` value types from `CodeEditorHighlightingCore`.
    ///
    /// ## Semantics (exposes the existing internal behavior — does not change it)
    ///
    /// The injected provider is used as the **primary** provider of the
    /// range-based highlighting controller. This is a *replace*, not an augment:
    /// while a provider is installed, the built-in regex / SwiftSyntax
    /// highlighter does **not** run as the primary source — the injected
    /// provider's tokens fully drive syntax styling. (This is distinct from the
    /// LSP integration, which layers semantic tokens on top as a *supplemental*
    /// provider at a higher priority while the built-in highlighter still runs.)
    ///
    /// Passing `nil` restores the built-in regex / SwiftSyntax highlighter as
    /// the primary provider.
    ///
    /// ## Enabling the range-based pipeline
    ///
    /// The range-store pipeline that this seam feeds is gated by configuration
    /// and must be enabled for the provider to paint:
    ///
    /// ```swift
    /// config.performance.usesRangeBasedHighlighting = true // instantiate the controller
    /// config.display.useRangeStoreHighlighting = true      // let the range applier paint text
    /// ```
    ///
    /// When those flags are off, the provider is retained but inert; it takes
    /// effect the next time the controller is (re)built with the flags on.
    ///
    /// - Parameter provider: The value provider to install, or `nil` to restore
    ///   the built-in highlighter.
    public func setExternalHighlightProvider(_ provider: (any HighlightRangeProviding)?) {
        // Identity guard: re-installing the same provider object (or nil over
        // nil) is a no-op, so the SwiftUI `.codeEditorHighlightProvider(_:)`
        // modifier can re-assert the provider on every view update cheaply
        // without tearing down and rebuilding the highlighting pipeline.
        if provider === highlightingController.externalHighlightProvider { return }

        highlightingController.externalHighlightProvider = provider

        // Force the range-based controller to reconstruct so the new primary
        // provider takes effect; `updateRangeBasedHighlightingConfiguration()`
        // reads the stored provider when it rebuilds.
        rangeBasedHighlightingController?.detach()
        rangeBasedHighlightingController = nil
        updateRangeBasedHighlightingConfiguration()
    }

    /// The value-oriented highlight provider currently installed via
    /// ``setExternalHighlightProvider(_:)``, or `nil` when the editor uses its
    /// built-in regex / SwiftSyntax highlighter.
    public var externalHighlightProvider: (any HighlightRangeProviding)? {
        highlightingController.externalHighlightProvider
    }
}
