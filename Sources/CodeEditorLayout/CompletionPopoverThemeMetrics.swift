import DesignKitTokens
import CodeEditorPlatform
import DesignKitThemes
import CoreGraphics
import Foundation

/// Value-typed bundle of theme-derived metrics for the completion
/// popover. The popover's content view and its cells read these values
/// when a theme is in flight; the value type lets the legacy
/// `CompletionCellTheme` stay in place as a transitional surface while
/// new draw paths consume the theme directly.
///
/// Reads from `theme.style.elements.element.active` for the selected row
/// background, `text.base` / `text.muted` for the primary and secondary
/// label colors, `borders.base` at `Tokens.Shape.strokeHairline` for the
/// outline, and `Tokens.Shape.radiusMD` for the corner radius.
public struct CompletionPopoverThemeMetrics: Hashable, Sendable {
    /// Background color for the selected row.
    public let selectedRowColor: PlatformColor

    /// Primary label color (item title).
    public let primaryTextColor: PlatformColor

    /// Secondary label color (item detail).
    public let secondaryTextColor: PlatformColor

    /// Popover outline color.
    public let borderColor: PlatformColor

    /// Popover outline width in points.
    public let borderWidth: CGFloat

    /// Popover corner radius in points.
    public let cornerRadius: CGFloat

    /// Build metrics from a theme.
    public init(theme: Theme) {
        self.selectedRowColor = PlatformColor(tokens: theme.style.elements.element.active)
        self.primaryTextColor = PlatformColor(tokens: theme.style.text.base)
        self.secondaryTextColor = PlatformColor(tokens: theme.style.text.muted)
        self.borderColor = PlatformColor(tokens: theme.style.borders.base)
        self.borderWidth = CGFloat(Tokens.Shape.strokeHairline)
        self.cornerRadius = CGFloat(Tokens.Shape.radiusMD)
    }
}
