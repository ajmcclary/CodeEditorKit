import CodeEditorDesignTokens
import CoreGraphics

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

extension NSColor {
    /// Build an sRGB `NSColor` from a `Tokens.Color`.
    public convenience init(tokens color: Tokens.Color) {
        self.init(
            srgbRed: CGFloat(color.red) / 255,
            green: CGFloat(color.green) / 255,
            blue: CGFloat(color.blue) / 255,
            alpha: CGFloat(color.alpha)
        )
    }
}
#endif

#if canImport(UIKit)
import UIKit

extension UIColor {
    /// Build an sRGB `UIColor` from a `Tokens.Color`.
    public convenience init(tokens color: Tokens.Color) {
        self.init(
            red: CGFloat(color.red) / 255,
            green: CGFloat(color.green) / 255,
            blue: CGFloat(color.blue) / 255,
            alpha: CGFloat(color.alpha)
        )
    }
}
#endif
