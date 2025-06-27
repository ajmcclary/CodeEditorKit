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

    public func color(forToken tokenName: TokenName) -> PlatformColor? {
        colors.color(forToken: tokenName)
    }

    public func font(forToken tokenName: TokenName) -> PlatformFont? {
        fonts.font(forToken: tokenName)
    }

    public struct Colors {
        public let colors: [TokenName: PlatformColor]

        public init(colors: [String: PlatformColor]) {
            self.colors = Dictionary(uniqueKeysWithValues: colors.map { key, value in 
                (TokenName(key), value)
            })
        }

        public init(bundle: Bundle, name: String) {
            #if canImport(AppKit)
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
            #else
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
            #endif
        }

        public func color(forToken tokenName: TokenName) -> PlatformColor? {
            colors[tokenName]
        }
    }

    public struct Fonts {
        public let fonts: [TokenName: PlatformFont]

        public init(fonts: [String: PlatformFont]) {
            self.fonts = Dictionary(uniqueKeysWithValues: fonts.map { key, value in 
                (TokenName(key), value)
            })
        }

        public init(bundle _: Bundle, name _: String) {
            func createMonospacedFont(weight: PlatformFont.Weight) -> PlatformFont {
                #if canImport(AppKit)
                return NSFont.monospacedSystemFont(ofSize: 0, weight: weight)
                #else
                return UIFont.monospacedSystemFont(ofSize: 0, weight: weight)
                #endif
            }
            
            fonts = [
                "plain": createMonospacedFont(weight: .regular),
                "boolean": createMonospacedFont(weight: .regular),
                "comment": createMonospacedFont(weight: .regular),
                "constructor": createMonospacedFont(weight: .medium),
                "function.call": createMonospacedFont(weight: .regular),
                "include": createMonospacedFont(weight: .regular),
                "keyword": createMonospacedFont(weight: .medium),
                "keyword.function": createMonospacedFont(weight: .medium),
                "keyword.return": createMonospacedFont(weight: .medium),
                "method": createMonospacedFont(weight: .regular),
                "number": createMonospacedFont(weight: .regular),
                "operator": createMonospacedFont(weight: .regular),
                "parameter": createMonospacedFont(weight: .regular),
                "punctuation.special": createMonospacedFont(weight: .regular),
                "string": createMonospacedFont(weight: .regular),
                "text.literal": createMonospacedFont(weight: .regular),
                "text.title": createMonospacedFont(weight: .medium),
                "type": createMonospacedFont(weight: .regular),
                "variable.builtin": createMonospacedFont(weight: .regular),
                "variable": createMonospacedFont(weight: .regular)
            ]
        }

        public func font(forToken tokenName: TokenName) -> PlatformFont? {
            fonts[tokenName]
        }
    }
}
