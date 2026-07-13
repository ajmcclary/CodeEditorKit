import DesignKitTokens
import DesignKitThemes
@testable import CodeEditorView
import Foundation
import Testing

@Suite("Theme.color(forToken:) resolver")
struct SyntaxColorLookupTests {
    @Test("Direct hit returns the SyntaxStyle.color")
    func directHit() {
        let theme = Theme.lcarsDark
        // LCARS Dark defines `keyword` directly.
        guard let expected = theme.style.syntax["keyword"]?.color else {
            Issue.record("Expected LCARS Dark to define syntax['keyword']")
            return
        }
        #expect(theme.color(forToken: "keyword") == expected)
    }

    @Test("Hierarchical fallback: function.method falls back to function")
    func hierarchicalFallbackFunctionMethod() {
        let theme = Theme.lcarsDark
        // LCARS Dark has `function` but not `function.method`.
        #expect(theme.style.syntax["function.method"] == nil)
        guard let parent = theme.style.syntax["function"]?.color else {
            Issue.record("Expected LCARS Dark to define syntax['function']")
            return
        }
        #expect(theme.color(forToken: "function.method") == parent)
        #expect(theme.color(forToken: "function.method.builtin") == parent)
    }

    @Test("Full miss falls through to style.editor.foreground")
    func fullMissFallsThrough() {
        let theme = Theme.lcarsDark
        let resolved = theme.color(forToken: "totally.unknown.token.foo")
        #expect(resolved == theme.style.editor.foreground)
    }

    @Test("Repeated lookups are stable (cache does not corrupt result)")
    func cachedAfterFirstHit() {
        let theme = Theme.lcarsDark
        let first = theme.color(forToken: "function.method")
        let second = theme.color(forToken: "function.method")
        let third = theme.color(forToken: "function")
        #expect(first == second)
        #expect(first == third)
    }

    @Test("Missing token: empty string falls through to foreground")
    func emptyTokenFallsThrough() {
        let theme = Theme.lcarsDark
        let resolved = theme.color(forToken: "")
        #expect(resolved == theme.style.editor.foreground)
    }
}
