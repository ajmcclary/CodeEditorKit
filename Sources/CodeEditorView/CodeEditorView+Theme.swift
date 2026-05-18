// MARK: - CodeEditorView Theme Application
//
// Push-model theme propagation. CodeEditorContainerView calls
// `apply(theme:)` on the text view; the equality-gated implementation here
// updates selection background (macOS), tintColor (iOS — UITextView
// renders the selection on top of tintColor with a system-defined alpha),
// and stores the applied theme for downstream consumers (per-run color via
// `SyntaxColorScheme.color(forToken:in:)`).

import CodeEditorPlatform
import CodeEditorTheming
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
        let themeChanged = appliedTheme != theme
        CodeEditorRenderingDiagnostics.log(
            "textView.apply.begin",
            textView: self,
            theme: theme,
            note: "themeChanged=\(themeChanged)"
        )
        if themeChanged {
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
            appearance = theme.appKitAppearance
            usesAdaptiveColorMappingForDarkAppearance = false
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

        stampThemeForeground(overwritingExistingForeground: themeChanged)
        CodeEditorRenderingDiagnostics.log(
            "textView.apply.afterForegroundStamp",
            textView: self,
            theme: theme,
            note: "themeChanged=\(themeChanged)"
        )
        if themeChanged {
            applySyntaxHighlighting()
        }
    }

    /// Stamps the applied theme's foreground colour onto every character in
    /// the text storage. Idempotent and safe to call repeatedly. Required
    /// after any `.string =` replacement, which wipes per-range attributes;
    /// TK2 glyph rendering will fall through to nothing otherwise. The seed
    /// can overwrite existing colours on theme changes because all previously
    /// themed token colours are stale; same-theme calls seed only gaps so
    /// token-specific colours survive content/configuration churn.
    package func stampThemeForeground(overwritingExistingForeground: Bool = false) {
        guard let theme = appliedTheme else { return }
        let length = textKitBridge.documentLength
        guard length > 0 else { return }

        let foreground = PlatformColor(tokens: theme.style.editor.foreground)
        let range = NSRange(location: 0, length: length)
        let attributes: [NSAttributedString.Key: Any] = [.foregroundColor: foreground]
        CodeEditorRenderingDiagnostics.log(
            "textView.stampForeground.begin",
            textView: self,
            theme: theme,
            note: "overwrite=\(overwritingExistingForeground) range={\(range.location),\(range.length)} foreground=\(foreground)"
        )
        if overwritingExistingForeground {
            textKitBridge.addPersistentAttributes(attributes, range: range)
            textKitBridge.addAttributes(attributes, range: range)
        } else {
            textKitBridge.addMissingPersistentAttributes(attributes, range: range)
            textKitBridge.addMissingRenderingAttributes(attributes, range: range)
        }
        CodeEditorRenderingDiagnostics.log(
            "textView.stampForeground.end",
            textView: self,
            theme: theme,
            note: "overwrite=\(overwritingExistingForeground)"
        )
    }
}

#if canImport(AppKit)
extension Theme {
    var appKitAppearance: NSAppearance? {
        NSAppearance(named: appearance == .dark ? .darkAqua : .aqua)
    }
}
#endif
