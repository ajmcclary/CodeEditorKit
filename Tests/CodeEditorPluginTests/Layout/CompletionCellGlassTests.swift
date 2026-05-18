import CodeEditorDesignTokens
@testable import CodeEditorLayout
import CodeEditorPlatform
@testable import CodeEditorPlugin
@testable import CodeEditorSwiftUI
import CodeEditorTheming
@testable import CodeEditorView
import Foundation
import Testing

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@Suite("Completion popover glass + themed metrics")
struct CompletionCellGlassTests {
    @Test("CompletionPopoverThemeMetrics: selected row = elements.element.active")
    @MainActor
    func selectedRowBackground() {
        let theme = Theme.lcarsDark
        let metrics = CompletionPopoverThemeMetrics(theme: theme)
        #expect(metrics.selectedRowColor == PlatformColor(tokens: theme.style.elements.element.active))
    }

    @Test("CompletionPopoverThemeMetrics: text colors = text.base + text.muted")
    @MainActor
    func cellTextColors() {
        let theme = Theme.lcarsDark
        let metrics = CompletionPopoverThemeMetrics(theme: theme)
        #expect(metrics.primaryTextColor == PlatformColor(tokens: theme.style.text.base))
        #expect(metrics.secondaryTextColor == PlatformColor(tokens: theme.style.text.muted))
    }

    @Test("CompletionPopoverThemeMetrics: border = borders.base at strokeHairline")
    @MainActor
    func borderColor() {
        let theme = Theme.lcarsDark
        let metrics = CompletionPopoverThemeMetrics(theme: theme)
        #expect(metrics.borderColor == PlatformColor(tokens: theme.style.borders.base))
        #expect(abs(metrics.borderWidth - CGFloat(Tokens.Shape.strokeHairline)) < 0.001)
    }

    @Test("CompletionPopoverThemeMetrics: corner radius = Tokens.Shape.radiusMD")
    @MainActor
    func cornerRadius() {
        let theme = Theme.lcarsDark
        let metrics = CompletionPopoverThemeMetrics(theme: theme)
        #expect(abs(metrics.cornerRadius - CGFloat(Tokens.Shape.radiusMD)) < 0.001)
    }

    @Test("_GlassSurface.themedTintColor = platform.glass.tint @ glass.opacity")
    @MainActor
    func glassSurfaceTint() {
        let surface = _GlassSurface(frame: .zero)
        let theme = Theme.lcarsDark
        surface.apply(theme: theme)
        let expected = PlatformColor(tokens: theme.platform.glass.tint)
            .withAlphaComponent(CGFloat(theme.platform.glass.opacity))
        #expect(surface.themedTintColor == expected)
    }

    @Test("UnifiedCompletionCellView.apply(theme:) refreshes colors from theme")
    @MainActor
    func cellViewAppliesTheme() {
        #if canImport(AppKit)
        let cell = UnifiedCompletionCellView()
        let theme = Theme.lcarsDark
        cell.apply(theme: theme)
        let metrics = CompletionPopoverThemeMetrics(theme: theme)
        #expect(cell.themedPrimaryTextColor == metrics.primaryTextColor)
        #expect(cell.themedSecondaryTextColor == metrics.secondaryTextColor)
        #endif
    }
}
