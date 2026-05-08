import CodeEditorDesignTokens
import Foundation

extension Theme {
    /// Resolves a `TokenName` to a `Tokens.Color` via hierarchical dotted
    /// fallback over `style.syntax`, ending at `style.editor.foreground`.
    ///
    /// On a miss the resolver drops the trailing dotted segment and retries.
    /// `function.method.builtin` → `function.method` → `function` → foreground.
    /// Result is cached per `Theme` identity to avoid repeated string-walks
    /// during large highlight passes.
    public func color(forToken token: TokenName) -> Tokens.Color {
        let key = token.description
        let id = SyntaxColorCache.key(for: self)
        if let cached = SyntaxColorCache.shared.lookup(themeID: id, token: key) {
            return cached
        }
        let resolved = Self.resolveSyntaxColor(token: key, in: self.style)
        SyntaxColorCache.shared.store(themeID: id, token: key, value: resolved)
        return resolved
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

/// Cache key derived from a Theme's value identity. Uses (name, appearance,
/// foregroundHex) as a stable, hashable surrogate; cache hits across calls
/// to identical-content Theme instances.
struct SyntaxColorCacheKey: Hashable, Sendable {
    let name: String
    let appearance: Theme.Appearance
    let foregroundHex: String
}

/// Process-wide syntax-color cache. Single shared instance; keys scope each
/// theme's hits separately.
///
/// `@unchecked Sendable` rationale: `entries` is the only mutable property
/// and every read/write below is bracketed by `lock.lock()`/`unlock()`. The
/// stored `Tokens.Color` values are value types (`Sendable`-conforming).
/// Combine-style synthesis isn't available because the dictionary is mutated
/// in place by `store(themeID:token:value:)`.
final class SyntaxColorCache: @unchecked Sendable {
    static let shared = SyntaxColorCache()

    private let lock = NSLock()
    private var entries: [SyntaxColorCacheKey: [String: Tokens.Color]] = [:]

    static func key(for theme: Theme) -> SyntaxColorCacheKey {
        SyntaxColorCacheKey(
            name: theme.name,
            appearance: theme.appearance,
            foregroundHex: theme.style.editor.foreground.hexString
        )
    }

    func lookup(themeID: SyntaxColorCacheKey, token: String) -> Tokens.Color? {
        lock.lock(); defer { lock.unlock() }
        return entries[themeID]?[token]
    }

    func store(themeID: SyntaxColorCacheKey, token: String, value: Tokens.Color) {
        lock.lock(); defer { lock.unlock() }
        entries[themeID, default: [:]][token] = value
    }
}
