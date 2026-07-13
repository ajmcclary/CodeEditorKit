import DesignKitTokens
import CodeEditorPlatform
import DesignKitThemes
import Foundation

/// Shared semantic theme state for native completion-cell implementations.
@MainActor
struct CompletionCellThemeState {
    private(set) var appliedTheme: Theme?
    private(set) var primaryTextColor: PlatformColor
    private(set) var secondaryTextColor: PlatformColor
    private(set) var borderColor: PlatformColor
    private(set) var borderWidth: CGFloat
    private(set) var cornerRadius: CGFloat

    init(fallback: CompletionCellTheme) {
        primaryTextColor = fallback.titleColor
        secondaryTextColor = fallback.detailColor
        borderColor = PlatformColors.separator
        borderWidth = CGFloat(Tokens.Shape.strokeHairline)
        cornerRadius = CGFloat(Tokens.Shape.radiusMD)
    }

    mutating func apply(theme: Theme) -> Bool {
        guard appliedTheme != theme else { return false }
        appliedTheme = theme
        let metrics = CompletionPopoverThemeMetrics(theme: theme)
        primaryTextColor = metrics.primaryTextColor
        secondaryTextColor = metrics.secondaryTextColor
        borderColor = metrics.borderColor
        borderWidth = metrics.borderWidth
        cornerRadius = metrics.cornerRadius
        return true
    }
}
