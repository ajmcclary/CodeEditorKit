// MARK: - CodeEditorView Theme Application
//
// Push-model theme propagation. CodeEditorContainerView calls
// `apply(theme:)` on the text view; the equality-gated implementation here
// updates selection background (macOS), tintColor (iOS — UITextView
// renders the selection on top of tintColor with a system-defined alpha),
// and stores the applied theme for downstream consumers (per-run color via
// `SyntaxColorScheme.color(forToken:in:)`).

import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

private enum CodeEditorViewThemeStorage {
    nonisolated(unsafe) static var key: UInt8 = 0
}

extension CodeEditorView {
    /// Theme last applied via `apply(theme:)`. nil before first apply.
    public var appliedTheme: Theme? {
        get {
            objc_getAssociatedObject(self, &CodeEditorViewThemeStorage.key) as? Theme
        }
        set {
            objc_setAssociatedObject(
                self,
                &CodeEditorViewThemeStorage.key,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    /// Apply a theme to the text view. Equality-gated; updates the
    /// selection-background attribute (macOS) or tintColor (iOS) so that
    /// the selection rendering follows the theme's `players[0]` colors.
    public func apply(theme: Theme) {
        if appliedTheme == theme { return }
        appliedTheme = theme
        let cursorColor = PlatformColor(tokens: theme.style.players[0].cursor)
        let selectionColor = PlatformColor(tokens: theme.style.players[0].selection)
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        var attrs = selectedTextAttributes
        attrs[.backgroundColor] = selectionColor
        selectedTextAttributes = attrs
        insertionPointColor = cursorColor
        #else
        // UITextView renders the selection background as `tintColor` with a
        // system-defined alpha multiplier. Per Q3=C in the spec, the
        // resulting α may differ slightly from `players[0].selection.alpha`.
        tintColor = cursorColor
        _ = selectionColor // selection-fill alpha is system-driven on iOS
        #endif
    }
}
