import CodeEditorDesignTokens
import CodeEditorPlatform
@testable import CodeEditorPlugin
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
        container.apply(theme: .lcarsDark)
        #expect(container.appliedTheme == Theme.lcarsDark)
    }

    @Test("apply(theme:) keeps stored theme stable on same-theme reapply")
    @MainActor
    func equalityGated() {
        let container = CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        container.apply(theme: .lcarsDark)
        let firstStored = container.appliedTheme
        container.apply(theme: .lcarsDark)
        #expect(container.appliedTheme == firstStored)
    }

    @Test("Same-theme container reapply re-stamps text storage foreground")
    @MainActor
    func sameThemeReapplyRestampsTextViewForeground() throws {
        let container = CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        container.textView.string = "alpha"
        container.apply(theme: .lcarsDark)

        let storage = try #require(container.textView.textContentStorage?.textStorage)
        storage.removeAttribute(.foregroundColor, range: NSRange(location: 0, length: storage.length))
        #expect(storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) == nil)

        container.apply(theme: .lcarsDark)

        #expect(storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) != nil)
    }

    @Test("Different themes update the stored value")
    @MainActor
    func differentThemesUpdate() {
        let container = CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        container.apply(theme: .lcarsDark)
        let fallback = Theme.fallback(appearance: .light)
        container.apply(theme: fallback)
        #expect(container.appliedTheme == fallback)
        #expect(container.appliedTheme != Theme.lcarsDark)
    }

    #if canImport(AppKit)
    @Test("apply(theme:) propagates to the macOS LineNumberRulerView renderer")
    @MainActor
    func applyThemePropagatesToRuler() async throws {
        let container = CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        // The scroll view + ruler are created in CodeEditorContainerView.init via
        // ContainerViewInitializer; pull the ruler out to read its renderer state.
        let scrollView = try #require(container.textView.enclosingScrollView)
        let ruler = try #require(scrollView.verticalRulerView as? LineNumberRulerView)

        container.apply(theme: .lcarsDark)

        let expected = PlatformColor(tokens: Theme.lcarsDark.style.editor.activeLineNumber)
        #expect(ruler.renderer.themedActiveLineNumberColor.cgColor == expected.cgColor)
    }

    @Test("apply(theme:) seeds TextKit2 rendering foreground across light-to-dark switches")
    @MainActor
    func applyThemeSeedsRenderingForeground() throws {
        let container = CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 900, height: 600))
        let textView = container.textView
        textView.string = "first line\nsecond line\nthird line"

        let light = try #require(ThemeFamily.bundled("zed-trek")?.theme(named: "LCARS Light"))
        container.apply(theme: light)
        #expect(renderingForegroundColor(in: textView)?.cgColor == PlatformColor(tokens: light.style.editor.foreground).cgColor)

        container.apply(theme: .lcarsDark)
        #expect(renderingForegroundColor(in: textView)?.cgColor == PlatformColor(tokens: Theme.lcarsDark.style.editor.foreground).cgColor)
    }

    @Test("Same-theme foreground seeding preserves existing syntax rendering colours")
    @MainActor
    func sameThemeForegroundSeedingPreservesSyntaxColors() throws {
        let container = CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 900, height: 600))
        let textView = container.textView
        textView.string = "keyword identifier"
        container.apply(theme: .lcarsDark)

        let syntaxRange = NSRange(location: 8, length: 1)
        let syntaxColor = PlatformColor.systemRed
        textView.textKitBridge.addAttributes([.foregroundColor: syntaxColor], range: syntaxRange)

        container.apply(theme: .lcarsDark)

        #expect(renderingForegroundColor(in: textView, location: syntaxRange.location)?.cgColor == syntaxColor.cgColor)
    }

    @Test("AppKit themed text view opts out of OS adaptive foreground remapping")
    @MainActor
    func appKitThemeDisablesAdaptiveForegroundRemapping() throws {
        let container = CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 900, height: 600))

        container.apply(theme: .lcarsDark)
        #expect(container.textView.usesAdaptiveColorMappingForDarkAppearance == false)
        #expect(container.textView.appearance?.name == NSAppearance.Name.darkAqua)

        let light = try #require(ThemeFamily.bundled("zed-trek")?.theme(named: "LCARS Light"))
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
