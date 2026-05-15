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

    /// Apply a theme to the text view. Equality-gated for the cheap colour
    /// setters; the storage foreground stamp always runs so a setText that
    /// wiped per-range attributes since the last call gets re-stamped with
    /// `style.editor.foreground`. Without that stamp, TextKit2 glyphs render
    /// transparent — `NSTextView.textColor` is not honoured as a glyph
    /// fallback for unattributed runs under TK2.
    public func apply(theme: Theme) {
        if appliedTheme != theme {
            appliedTheme = theme
            let cursorColor = PlatformColor(tokens: theme.style.players[0].cursor)
            let selectionColor = PlatformColor(tokens: theme.style.players[0].selection)
            let foregroundColor = PlatformColor(tokens: theme.style.editor.foreground)
            let backgroundColor = PlatformColor(tokens: theme.style.editor.background)

            // Base text + background. Both AppKit and UIKit read these for
            // their non-glyph chrome (selection rendering compositing,
            // backgroundDrawing, etc.).
            textColor = foregroundColor
            self.backgroundColor = backgroundColor

            // Keep newly-inserted text in the theme's foreground until the
            // syntax pass adds per-token rendering attributes.
            var typingAttrs = typingAttributes
            typingAttrs[.foregroundColor] = foregroundColor
            typingAttributes = typingAttrs

            #if canImport(AppKit)
            var attrs = selectedTextAttributes
            attrs[.backgroundColor] = selectionColor
            selectedTextAttributes = attrs
            insertionPointColor = cursorColor
            #else
            // UITextView renders the selection background as `tintColor`
            // with a system-defined alpha multiplier.
            tintColor = cursorColor
            _ = selectionColor // selection-fill alpha is system-driven on iOS
            #endif
        }

        stampThemeForeground()
    }

    /// Stamps the applied theme's foreground colour onto every character in
    /// the text storage. Idempotent and safe to call repeatedly. Required
    /// after any `.string =` replacement, which wipes per-range attributes;
    /// TK2 glyph rendering will fall through to nothing otherwise.
    internal func stampThemeForeground() {
        guard let theme = appliedTheme,
              let textStorage = textContentStorage?.textStorage,
              textStorage.length > 0 else { return }
        let foreground = PlatformColor(tokens: theme.style.editor.foreground)
        let range = NSRange(location: 0, length: textStorage.length)
        textStorage.beginEditing()
        textStorage.addAttribute(.foregroundColor, value: foreground, range: range)
        textStorage.endEditing()
    }
}
