import DesignKitTokens
import CodeEditorPlatform
@testable import CodeEditorSyntaxHighlighting
import DesignKitThemes
@testable import CodeEditorView
import Foundation
import Testing

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@Suite("Per-run color + selection fill")
struct SyntaxColorAndSelectionTests {
    @Test("SyntaxColorScheme.color(forToken:in:) routes through Theme.color(forToken:)")
    @MainActor
    func highlightUsesResolver() {
        let theme = Theme.lcarsDark
        let result = SyntaxColorScheme.color(forToken: "keyword", in: theme)
        #expect(result == PlatformColor(tokens: theme.color(forToken: "keyword")))
    }

    @Test("SyntaxColorScheme.color(forToken:in:) hierarchically falls back")
    @MainActor
    func highlightHierarchicalFallback() {
        let theme = Theme.lcarsDark
        let parent = SyntaxColorScheme.color(forToken: "keyword", in: theme)
        let child = SyntaxColorScheme.color(forToken: "keyword.control.deeply.nested", in: theme)
        #expect(child == parent)
    }

    #if canImport(AppKit)
    @Test("CodeEditorView selectedTextAttributes background = players[0].selection on macOS")
    @MainActor
    func selectionBackgroundFromTheme() {
        let view = CodeEditorView()
        let theme = Theme.lcarsDark
        view.apply(theme: theme)
        let attrs = view.selectedTextAttributes
        let bg = attrs[.backgroundColor] as? NSColor
        #expect(bg == NSColor(tokens: theme.style.players[0].selection))
    }

    @Test("CodeEditorView equality-gated apply is a no-op on second identical call")
    @MainActor
    func editorEqualityGate() {
        let view = CodeEditorView()
        view.apply(theme: .lcarsDark)
        let firstStored = view.appliedTheme
        view.apply(theme: .lcarsDark)
        #expect(view.appliedTheme == firstStored)
    }
    #endif

    #if canImport(UIKit)
    @Test("CodeEditorView tintColor follows players[0].cursor on iOS")
    @MainActor
    func tintColorFromThemeOniOS() {
        let view = CodeEditorView()
        let theme = Theme.lcarsDark
        view.apply(theme: theme)
        #expect(view.tintColor == UIColor(tokens: theme.style.players[0].cursor))
    }
    #endif
}
