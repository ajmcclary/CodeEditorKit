import CodeEditorDesignTokens
import SwiftUI

/// SwiftUI bridge accessors for the new `Theme`. These four properties
/// preserve the surface that the legacy `CodeEditorSwiftUITheme` exposed
/// so the existing chrome pipeline (factory methods, coordinators,
/// platform views) keeps working when `CodeEditorSwiftUITheme` is removed.
extension Theme {
    /// Editor canvas background as a `SwiftUI.Color`.
    public var backgroundColor: Color {
        Color(tokens: style.editor.background)
    }

    /// Editor text foreground as a `SwiftUI.Color`.
    public var textColor: Color {
        Color(tokens: style.editor.foreground)
    }

    /// Gutter line-number color as a `SwiftUI.Color`.
    public var lineNumberColor: Color {
        Color(tokens: style.editor.lineNumber)
    }

    /// Active-line highlight color as a `SwiftUI.Color`.
    public var selectedLineColor: Color {
        Color(tokens: style.editor.activeLineBackground)
    }
}

extension Theme {
    /// Library default theme. Resolves to `Theme.lcarsDark`.
    public static var `default`: Theme { lcarsDark }

    /// Conventional dark theme alias. Resolves to `Theme.lcarsDark`.
    public static var dark: Theme { lcarsDark }
}

extension Color {
    /// Build a `SwiftUI.Color` from a `Tokens.Color` (sRGB).
    public init(tokens color: Tokens.Color) {
        self.init(
            .sRGB,
            red: Double(color.red) / 255,
            green: Double(color.green) / 255,
            blue: Double(color.blue) / 255,
            opacity: color.alpha
        )
    }
}
