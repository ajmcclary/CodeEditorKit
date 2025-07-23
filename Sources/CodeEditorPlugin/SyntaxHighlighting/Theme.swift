import Foundation

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Represents a color and font theme for syntax highlighting.
///
/// A theme defines the visual appearance of code in the editor by specifying colors
/// and fonts for different token types. Themes can be loaded from asset catalogs or
/// created programmatically.
///
/// ## Creating Themes
///
/// ### From Asset Catalog
/// ```swift
/// let theme = Theme(
///     colors: Theme.Colors(bundle: .main, name: "MyTheme"),
///     fonts: Theme.Fonts()
/// )
/// ```
///
/// ### Programmatically
/// ```swift
/// let colors: [String: PlatformColor] = [
///     "keyword": .systemPurple,
///     "string": .systemRed,
///     "comment": .secondaryLabel,
///     "type": .systemGreen
/// ]
/// 
/// let theme = Theme(
///     colors: Theme.Colors(colors: colors),
///     fonts: Theme.Fonts()
/// )
/// ```
///
/// ## Token Types
///
/// Themes support coloring for various token types:
/// - **Keywords**: `keyword`, `keyword.function`, `keyword.return`
/// - **Literals**: `string`, `number`, `boolean`
/// - **Types**: `type`, `constructor`
/// - **Functions**: `function.call`, `method`
/// - **Comments**: `comment`
/// - **Variables**: `variable`, `variable.builtin`, `parameter`
/// - **Operators**: `operator`, `punctuation.special`
///
/// - SeeAlso: `TokenName`, `CodeEditorSwiftUITheme`
public struct Theme {
    // MARK: - Props

    public let colors: Colors
    public let fonts: Fonts

    // MARK: - Lifecycle

    public init(colors: Colors, fonts: Fonts) {
        self.colors = colors
        self.fonts = fonts
    }

    /// Returns the color for a specific token type.
    ///
    /// - Parameter tokenName: The token type to get the color for
    /// - Returns: The color for the token, or nil if not defined
    ///
    /// ## Example
    ///
    /// ```swift
    /// let keywordColor = theme.color(forToken: TokenName("keyword"))
    /// let stringColor = theme.color(forToken: TokenName("string"))
    /// ```
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
            // Use platform abstraction for named color loading
            let tokenTypes = [
                "plain", "boolean", "comment", "constructor", "function.call",
                "include", "keyword", "keyword.function", "keyword.return",
                "method", "number", "operator", "parameter", "punctuation.special",
                "string", "text.literal", "text.title", "type",
                "variable.builtin", "variable"
            ]

            var colorDict: [String: PlatformColor] = [:]

            for tokenType in tokenTypes {
                let colorName = "\(name)/\(tokenType)"
                #if canImport(AppKit) && !targetEnvironment(macCatalyst)
                if let color = PlatformColor(named: colorName, bundle: bundle) {
                    colorDict[tokenType] = color
                } else {
                    // Fallback to semantic color based on token type
                    colorDict[tokenType] = Self.semanticFallbackColor(for: tokenType)
                }
                #elseif canImport(UIKit)
                if let color = PlatformColor(named: colorName, in: bundle, compatibleWith: nil) {
                    colorDict[tokenType] = color
                } else {
                    // Fallback to semantic color based on token type
                    colorDict[tokenType] = Self.semanticFallbackColor(for: tokenType)
                }
                #endif
            }

            self.init(colors: colorDict)
        }

        /// Provides semantic fallback colors when theme colors are not available
        private static func semanticFallbackColor(for tokenType: String) -> PlatformColor {
            switch tokenType {
            case "plain", "text.literal":
                return PlatformColors.label

            case "comment":
                return PlatformColors.secondaryLabel

            case "keyword", "keyword.function", "keyword.return":
                return PlatformColors.systemPurple

            case "string":
                return PlatformColors.systemRed

            case "number", "boolean":
                return PlatformColors.systemBlue

            case "type", "constructor":
                return PlatformColors.systemGreen

            case "function.call", "method":
                return PlatformColors.systemTeal

            case "operator", "punctuation.special":
                return PlatformColors.systemOrange

            case "parameter", "variable", "variable.builtin":
                return PlatformColors.systemIndigo

            case "include":
                return PlatformColors.systemPink

            case "text.title":
                return PlatformColors.label

            default:
                return PlatformColors.label
            }
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
            // Use platform abstraction for font creation
            let regularFont = PlatformFonts.monospacedSystemFont(ofSize: 0, weight: .regular)
            let mediumFont = PlatformFonts.monospacedSystemFont(ofSize: 0, weight: .medium)

            fonts = [
                "plain": regularFont,
                "boolean": regularFont,
                "comment": regularFont,
                "constructor": mediumFont,
                "function.call": regularFont,
                "include": regularFont,
                "keyword": mediumFont,
                "keyword.function": mediumFont,
                "keyword.return": mediumFont,
                "method": regularFont,
                "number": regularFont,
                "operator": regularFont,
                "parameter": regularFont,
                "punctuation.special": regularFont,
                "string": regularFont,
                "text.literal": regularFont,
                "text.title": mediumFont,
                "type": regularFont,
                "variable.builtin": regularFont,
                "variable": regularFont
            ]
        }

        public func font(forToken tokenName: TokenName) -> PlatformFont? {
            fonts[tokenName]
        }
    }
}
