import CodeEditorPlatform
@testable import CodeEditorView
import DesignKitThemes
import DesignKitTokens
import Foundation
import Testing

#if canImport(AppKit)
import AppKit
#endif

@Suite("apply(theme:) propagation")
struct ApplyThemePropagationTests {
    @Test("CodeEditorContainerView stores the applied theme")
    @MainActor
    func storesAppliedTheme() {
        let container = CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        #expect(container.appliedTheme == nil)
        container.apply(theme: .dark)
        #expect(container.appliedTheme == Theme.dark)
    }

    @Test("apply(theme:) keeps stored theme stable on same-theme reapply")
    @MainActor
    func equalityGated() {
        let container = CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        container.apply(theme: .dark)
        let firstStored = container.appliedTheme
        container.apply(theme: .dark)
        #expect(container.appliedTheme == firstStored)
    }

    /// A wholesale text replacement drops per-range attributes, so the next
    /// same-theme apply re-stamps the foreground. (It no longer re-stamps on
    /// every same-theme apply: that walked the whole document on every
    /// SwiftUI update.)
    @Test("Same-theme container reapply re-stamps text storage foreground after a text replacement")
    @MainActor
    func sameThemeReapplyRestampsTextViewForeground() throws {
        let container = CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        container.textView.string = "alpha"
        container.apply(theme: .dark)

        // Plain attributed text carries no foreground.
        container.textView.attributedText = NSAttributedString(string: "replaced text")
        let storage = try #require(container.textView.textContentStorage?.textStorage)
        #expect(storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) == nil)

        container.apply(theme: .dark)

        #expect(storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) != nil)
    }

    @Test("Different themes update the stored value")
    @MainActor
    func differentThemesUpdate() {
        let container = CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        container.apply(theme: .dark)
        let fallback = Theme.light
        container.apply(theme: fallback)
        #expect(container.appliedTheme == fallback)
        #expect(container.appliedTheme != Theme.dark)
    }

    #if canImport(AppKit)
    @Test("apply(theme:) propagates to the macOS LineNumberRulerView renderer")
    @MainActor
    func applyThemePropagatesToGutter() async throws {
        let container = CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let gutter = try #require(container.macLineNumberRulerView)

        container.apply(theme: .dark)

        let expected = PlatformColor(tokens: Theme.dark.style.editor.activeLineNumber)
        #expect(gutter.renderer.themedActiveLineNumberColor.cgColor == expected.cgColor)
    }

    @Test("apply(theme:) seeds TextKit2 rendering foreground across light-to-dark switches")
    @MainActor
    func applyThemeSeedsRenderingForeground() throws {
        let container = CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 900, height: 600))
        let textView = container.textView
        textView.string = "first line\nsecond line\nthird line"

        let light = Theme.light
        container.apply(theme: light)
        #expect(renderingForegroundColor(in: textView)?.cgColor == PlatformColor(tokens: light.style.editor.foreground).cgColor)

        container.apply(theme: .dark)
        #expect(renderingForegroundColor(in: textView)?.cgColor == PlatformColor(tokens: Theme.dark.style.editor.foreground).cgColor)
    }

    @Test("Same-theme foreground seeding preserves existing syntax rendering colours")
    @MainActor
    func sameThemeForegroundSeedingPreservesSyntaxColors() throws {
        let container = CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 900, height: 600))
        let textView = container.textView
        textView.string = "keyword identifier"
        container.apply(theme: .dark)

        let syntaxRange = NSRange(location: 8, length: 1)
        let syntaxColor = PlatformColor.systemRed
        textView.textKitBridge.addAttributes([.foregroundColor: syntaxColor], range: syntaxRange)

        container.apply(theme: .dark)

        #expect(renderingForegroundColor(in: textView, location: syntaxRange.location)?.cgColor == syntaxColor.cgColor)
    }

    @Test("AppKit themed text view opts out of OS adaptive foreground remapping")
    @MainActor
    func appKitThemeDisablesAdaptiveForegroundRemapping() throws {
        let container = CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 900, height: 600))

        container.apply(theme: .dark)
        #expect(container.textView.usesAdaptiveColorMappingForDarkAppearance == false)
        #expect(container.textView.appearance?.name == NSAppearance.Name.darkAqua)

        let light = Theme.light
        container.apply(theme: light)
        #expect(container.textView.usesAdaptiveColorMappingForDarkAppearance == false)
        #expect(container.textView.appearance?.name == NSAppearance.Name.aqua)
    }

    @MainActor
    private func renderingForegroundColor(in textView: CodeEditorView, location: Int = 0) -> PlatformColor? {
        guard let textLayoutManager = textView.textLayoutManager,
              let textRange = textView.textKitBridge.textRangeFromNSRange(NSRange(location: location, length: 1))
        else {
            return nil
        }

        textLayoutManager.ensureLayout(for: textRange)
        var foreground: PlatformColor?
        textLayoutManager.enumerateRenderingAttributes(from: textRange.location, reverse: false) { _, attributes, attributeRange in
            guard attributeRange.intersects(textRange) else { return true }
            foreground = attributes[.foregroundColor] as? PlatformColor
            return false
        }
        return foreground
    }
    #endif
}
