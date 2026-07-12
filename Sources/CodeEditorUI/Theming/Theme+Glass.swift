import CodeEditorDesignTokens
import CodeEditorSwiftUI
import CodeEditorTheming
import SwiftUI

/// SwiftUI accessors for `Theme.platform.glass` and the popover shadow.
///
/// Liquid Glass surfaces (`PlatformGlassSurface`) read `glassTintColor` +
/// `glassOpacity` from the active theme. Popovers (command palette,
/// completion menu) read `popoverShadow` for their drop shadow.
extension Theme {
    /// Tint color blended into the Liquid Glass material.
    public var glassTintColor: Color {
        Color(tokens: platform.glass.tint)
    }

    /// Glass tint opacity in `0...1`.
    public var glassOpacity: Double {
        platform.glass.opacity
    }

    /// Popover-class drop shadow as a SwiftUI-friendly tuple.
    ///
    /// The tuple's components map to `View.shadow(color:radius:x:y:)`
    /// where `radius == blur`.
    public var popoverShadow: (color: Color, blur: CGFloat, x: CGFloat, y: CGFloat) {
        let source = platform.shadows.popover
        return (
            color: Color(tokens: source.color),
            blur: CGFloat(source.blur),
            x: CGFloat(source.xOffset),
            y: CGFloat(source.yOffset)
        )
    }
}
