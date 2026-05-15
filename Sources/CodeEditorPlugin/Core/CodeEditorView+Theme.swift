// MARK: - CodeEditorView Theme Application
//
// Push-model theme propagation. CodeEditorContainerView calls
// `apply(theme:)` on the text view; the equality-gated implementation here
// updates selection background (macOS), tintColor (iOS — UITextView
// renders the selection on top of tintColor with a system-defined alpha),
// and stores the applied theme for downstream consumers (per-run color via
// `SyntaxColorScheme.color(forToken:in:)`).

import Foundation
#if canImport(AppKit)
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
    /// selection-background attribute (macOS) or tintColor (iOS), sets the
    /// base text foreground from `style.editor.foreground` so untokenized
    /// ranges render visibly, and stores the applied theme for downstream
    /// consumers.
    public func apply(theme: Theme) {
        if appliedTheme == theme { return }
        appliedTheme = theme
        let cursorColor = PlatformColor(tokens: theme.style.players[0].cursor)
        let selectionColor = PlatformColor(tokens: theme.style.players[0].selection)
        let foregroundColor = PlatformColor(tokens: theme.style.editor.foreground)
        let backgroundColor = PlatformColor(tokens: theme.style.editor.background)

        // Base text + background. Without this the text view falls back to
        // system label/background, which goes invisible on dark themes when
        // the editor's effective appearance disagrees with the theme's
        // background.
        textColor = foregroundColor
        self.backgroundColor = backgroundColor

        // Typing attributes for newly-inserted text — keeps the caret colour
        // matched even before the syntax pass adds rendering attributes.
        var typingAttrs = typingAttributes
        typingAttrs[.foregroundColor] = foregroundColor
        typingAttributes = typingAttrs

        #if canImport(AppKit)
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
