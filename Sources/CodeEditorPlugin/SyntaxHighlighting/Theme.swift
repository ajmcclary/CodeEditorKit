#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

public struct Theme {
    // MARK: - Props

    public let colors: Colors
    public let fonts: Fonts

    // MARK: - Lifecycle

    public init(colors: Colors, fonts: Fonts) {
        self.colors = colors
        self.fonts = fonts
    }

    #if canImport(AppKit)
    public func color(forToken tokenName: TokenName) -> NSColor? {
        colors.color(forToken: tokenName)
    }

    public func font(forToken tokenName: TokenName) -> NSFont? {
        fonts.font(forToken: tokenName)
    }
    #elseif canImport(UIKit)
    public func color(forToken tokenName: TokenName) -> UIColor? {
        colors.color(forToken: tokenName)
    }

    public func font(forToken tokenName: TokenName) -> UIFont? {
        fonts.font(forToken: tokenName)
    }
    #endif

    public struct Colors {
        #if canImport(AppKit)
        public let colors: [TokenName: NSColor]

        public init(colors: [String: NSColor]) {
            self.colors = Dictionary(uniqueKeysWithValues: colors.map { key, value in (TokenName(key), value) })
        }
        #elseif canImport(UIKit)
        public let colors: [TokenName: UIColor]

        public init(colors: [String: UIColor]) {
            self.colors = Dictionary(uniqueKeysWithValues: colors.map { key, value in (TokenName(key), value) })
        }
        #endif

        #if canImport(AppKit)
        public init(bundle: Bundle, name: String) {
            colors = [
                "plain": NSColor(named: "\(name)/plain", bundle: bundle)!,
                "boolean": NSColor(named: "\(name)/boolean", bundle: bundle)!,
                "comment": NSColor(named: "\(name)/comment", bundle: bundle)!,
                "constructor": NSColor(named: "\(name)/constructor", bundle: bundle)!,
                "function.call": NSColor(named: "\(name)/function.call", bundle: bundle)!,
                "include": NSColor(named: "\(name)/include", bundle: bundle)!,
                "keyword": NSColor(named: "\(name)/keyword", bundle: bundle)!,
                "keyword.function": NSColor(named: "\(name)/keyword.function", bundle: bundle)!,
                "keyword.return": NSColor(named: "\(name)/keyword.return", bundle: bundle)!,
                "method": NSColor(named: "\(name)/method", bundle: bundle)!,
                "number": NSColor(named: "\(name)/number", bundle: bundle)!,
                "operator": NSColor(named: "\(name)/operator", bundle: bundle)!,
                "parameter": NSColor(named: "\(name)/parameter", bundle: bundle)!,
                "punctuation.special": NSColor(named: "\(name)/punctuation.special", bundle: bundle)!,
                "string": NSColor(named: "\(name)/string", bundle: bundle)!,
                "text.literal": NSColor(named: "\(name)/text.literal", bundle: bundle)!,
                "text.title": NSColor(named: "\(name)/text.title", bundle: bundle)!,
                "type": NSColor(named: "\(name)/type", bundle: bundle)!,
                "variable.builtin": NSColor(named: "\(name)/variable.builtin", bundle: bundle)!,
                "variable": NSColor(named: "\(name)/variable", bundle: bundle)!
            ]
        }

        public func color(forToken tokenName: TokenName) -> NSColor? {
            colors[tokenName]
        }
        #elseif canImport(UIKit)
        public init(bundle: Bundle, name: String) {
            colors = [
                "plain": UIColor(named: "\(name)/plain", in: bundle, compatibleWith: nil)!,
                "boolean": UIColor(named: "\(name)/boolean", in: bundle, compatibleWith: nil)!,
                "comment": UIColor(named: "\(name)/comment", in: bundle, compatibleWith: nil)!,
                "constructor": UIColor(named: "\(name)/constructor", in: bundle, compatibleWith: nil)!,
                "function.call": UIColor(named: "\(name)/function.call", in: bundle, compatibleWith: nil)!,
                "include": UIColor(named: "\(name)/include", in: bundle, compatibleWith: nil)!,
                "keyword": UIColor(named: "\(name)/keyword", in: bundle, compatibleWith: nil)!,
                "keyword.function": UIColor(named: "\(name)/keyword.function", in: bundle, compatibleWith: nil)!,
                "keyword.return": UIColor(named: "\(name)/keyword.return", in: bundle, compatibleWith: nil)!,
                "method": UIColor(named: "\(name)/method", in: bundle, compatibleWith: nil)!,
                "number": UIColor(named: "\(name)/number", in: bundle, compatibleWith: nil)!,
                "operator": UIColor(named: "\(name)/operator", in: bundle, compatibleWith: nil)!,
                "parameter": UIColor(named: "\(name)/parameter", in: bundle, compatibleWith: nil)!,
                "punctuation.special": UIColor(named: "\(name)/punctuation.special", in: bundle, compatibleWith: nil)!,
                "string": UIColor(named: "\(name)/string", in: bundle, compatibleWith: nil)!,
                "text.literal": UIColor(named: "\(name)/text.literal", in: bundle, compatibleWith: nil)!,
                "text.title": UIColor(named: "\(name)/text.title", in: bundle, compatibleWith: nil)!,
                "type": UIColor(named: "\(name)/type", in: bundle, compatibleWith: nil)!,
                "variable.builtin": UIColor(named: "\(name)/variable.builtin", in: bundle, compatibleWith: nil)!,
                "variable": UIColor(named: "\(name)/variable", in: bundle, compatibleWith: nil)!
            ]
        }

        public func color(forToken tokenName: TokenName) -> UIColor? {
            colors[tokenName]
        }
        #endif
    }

    public struct Fonts {
        #if canImport(AppKit)
        public let fonts: [TokenName: NSFont]

        public init(fonts: [String: NSFont]) {
            self.fonts = Dictionary(uniqueKeysWithValues: fonts.map { key, value in (TokenName(key), value) })
        }
        #elseif canImport(UIKit)
        public let fonts: [TokenName: UIFont]

        public init(fonts: [String: UIFont]) {
            self.fonts = Dictionary(uniqueKeysWithValues: fonts.map { key, value in (TokenName(key), value) })
        }
        #endif

        #if canImport(AppKit)
        public init(bundle _: Bundle, name _: String) {
            fonts = [
                "plain": NSFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "boolean": NSFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "comment": NSFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "constructor": NSFont.monospacedSystemFont(ofSize: 0, weight: .medium),
                "function.call": NSFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "include": NSFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "keyword": NSFont.monospacedSystemFont(ofSize: 0, weight: .medium),
                "keyword.function": NSFont.monospacedSystemFont(ofSize: 0, weight: .medium),
                "keyword.return": NSFont.monospacedSystemFont(ofSize: 0, weight: .medium),
                "method": NSFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "number": NSFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "operator": NSFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "parameter": NSFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "punctuation.special": NSFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "string": NSFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "text.literal": NSFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "text.title": NSFont.monospacedSystemFont(ofSize: 0, weight: .medium),
                "type": NSFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "variable.builtin": NSFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "variable": NSFont.monospacedSystemFont(ofSize: 0, weight: .regular)
            ]
        }

        public func font(forToken tokenName: TokenName) -> NSFont? {
            fonts[tokenName]
        }
        #elseif canImport(UIKit)
        public init(bundle _: Bundle, name _: String) {
            fonts = [
                "plain": UIFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "boolean": UIFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "comment": UIFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "constructor": UIFont.monospacedSystemFont(ofSize: 0, weight: .medium),
                "function.call": UIFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "include": UIFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "keyword": UIFont.monospacedSystemFont(ofSize: 0, weight: .medium),
                "keyword.function": UIFont.monospacedSystemFont(ofSize: 0, weight: .medium),
                "keyword.return": UIFont.monospacedSystemFont(ofSize: 0, weight: .medium),
                "method": UIFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "number": UIFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "operator": UIFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "parameter": UIFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "punctuation.special": UIFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "string": UIFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "text.literal": UIFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "text.title": UIFont.monospacedSystemFont(ofSize: 0, weight: .medium),
                "type": UIFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "variable.builtin": UIFont.monospacedSystemFont(ofSize: 0, weight: .regular),
                "variable": UIFont.monospacedSystemFont(ofSize: 0, weight: .regular)
            ]
        }

        public func font(forToken tokenName: TokenName) -> UIFont? {
            fonts[tokenName]
        }
        #endif
    }
}
