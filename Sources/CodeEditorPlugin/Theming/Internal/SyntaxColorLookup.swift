import CodeEditorDesignTokens
import Foundation

extension Theme {
    /// Resolves a `TokenName` to a `Tokens.Color` via hierarchical dotted
    /// fallback over `style.syntax`, ending at `style.editor.foreground`.
    ///
    /// On a miss the resolver drops the trailing dotted segment and retries.
    /// `function.method.builtin` → `function.method` → `function` → foreground.
    /// The lookup is pure and does not rely on process-global mutable cache
    /// state, keeping theme resolution scoped to the `Theme` value.
    public func color(forToken token: TokenName) -> Tokens.Color {
        Self.resolveSyntaxColor(token: token.description, in: self.style)
    }

    /// Hierarchical lookup. Strips trailing dotted segments on miss.
    static func resolveSyntaxColor(token: String, in style: ThemeStyle) -> Tokens.Color {
        var probe = token
        while !probe.isEmpty {
            if let entry = style.syntax[probe], let color = entry.color {
                return color
            }
            guard let dot = probe.lastIndex(of: ".") else { break }
            probe = String(probe[..<dot])
        }
        return style.editor.foreground
    }
}
