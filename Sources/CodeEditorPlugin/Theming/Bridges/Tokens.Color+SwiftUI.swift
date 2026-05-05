import CodeEditorDesignTokens
import SwiftUI

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
