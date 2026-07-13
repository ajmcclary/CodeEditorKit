import DesignKitTokens
import DesignKitThemes
import Foundation

extension Theme {
    /// Resolves a `TokenName` to a `Tokens.Color` via hierarchical dotted
    /// fallback over `style.syntax`, ending at `style.editor.foreground`.
    public func color(forToken token: TokenName) -> Tokens.Color {
        Self.resolveSyntaxColor(token: token.description, in: self.style)
    }
}
