// swiftlint:disable object_literal
// This file uses programmatic color definitions for cross-platform compatibility

import CodeEditorLanguages
import CodeEditorPlatform
import DesignKitThemes
import DesignKitTokens
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Color scheme for syntax highlighting
public struct SyntaxColorScheme: Sendable {
    // MARK: - Properties

    public let keyword: PlatformColor
    public let identifier: PlatformColor
    public let string: PlatformColor
    public let number: PlatformColor
    public let comment: PlatformColor
    public let type: PlatformColor
    public let function: PlatformColor
    public let property: PlatformColor
    public let `operator`: PlatformColor
    public let punctuation: PlatformColor
    public let preprocessor: PlatformColor
    public let error: PlatformColor
    public let plain: PlatformColor

    // MARK: - Initialization

    public init(
        keyword: PlatformColor,
        identifier: PlatformColor,
        string: PlatformColor,
        number: PlatformColor,
        comment: PlatformColor,
        type: PlatformColor,
        function: PlatformColor,
        property: PlatformColor,
        operator: PlatformColor,
        punctuation: PlatformColor,
        preprocessor: PlatformColor,
        error: PlatformColor,
        plain: PlatformColor
    ) {
        self.keyword = keyword
        self.identifier = identifier
        self.string = string
        self.number = number
        self.comment = comment
        self.type = type
        self.function = function
        self.property = property
        self.operator = `operator`
        self.punctuation = punctuation
        self.preprocessor = preprocessor
        self.error = error
        self.plain = plain
    }

    // MARK: - Default Schemes

    /// Default color scheme with platform-appropriate colors
    public static let `default`: SyntaxColorScheme = {
        #if canImport(UIKit)
        return Self(
            keyword: .systemPurple,
            identifier: .label,
            string: .systemRed,
            number: .systemBlue,
            comment: .systemGreen,
            type: .systemTeal,
            function: .systemIndigo,
            property: .systemOrange,
            operator: .systemBrown,
            punctuation: .secondaryLabel,
            preprocessor: .systemPink,
            error: .systemRed,
            plain: .label
        )
        #else
        return Self(
            keyword: .systemPurple,
            identifier: .labelColor,
            string: .systemRed,
            number: .systemBlue,
            comment: .systemGreen,
            type: .systemTeal,
            function: .systemIndigo,
            property: .systemOrange,
            operator: .systemBrown,
            punctuation: .secondaryLabelColor,
            preprocessor: .systemPink,
            error: .systemRed,
            plain: .labelColor
        )
        #endif
    }()

    /// Dark mode optimized color scheme
    public static let dark: SyntaxColorScheme = {
        #if canImport(UIKit)
        return Self(
            keyword: UIColor(red: 0.68, green: 0.18, blue: 0.89, alpha: 1.0),
            identifier: UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0),
            string: UIColor(red: 0.98, green: 0.39, blue: 0.40, alpha: 1.0),
            number: UIColor(red: 0.86, green: 0.72, blue: 0.26, alpha: 1.0),
            comment: UIColor(red: 0.42, green: 0.47, blue: 0.53, alpha: 1.0),
            type: UIColor(red: 0.56, green: 0.84, blue: 0.84, alpha: 1.0),
            function: UIColor(red: 0.40, green: 0.62, blue: 0.90, alpha: 1.0),
            property: UIColor(red: 0.84, green: 0.60, blue: 0.13, alpha: 1.0),
            operator: UIColor(red: 0.70, green: 0.70, blue: 0.76, alpha: 1.0),
            punctuation: UIColor(red: 0.60, green: 0.60, blue: 0.66, alpha: 1.0),
            preprocessor: UIColor(red: 0.75, green: 0.54, blue: 0.89, alpha: 1.0),
            error: UIColor(red: 1.0, green: 0.27, blue: 0.27, alpha: 1.0),
            plain: UIColor(red: 0.85, green: 0.85, blue: 0.87, alpha: 1.0)
        )
        #else
        return Self(
            keyword: NSColor(red: 0.68, green: 0.18, blue: 0.89, alpha: 1.0),
            identifier: NSColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0),
            string: NSColor(red: 0.98, green: 0.39, blue: 0.40, alpha: 1.0),
            number: NSColor(red: 0.86, green: 0.72, blue: 0.26, alpha: 1.0),
            comment: NSColor(red: 0.42, green: 0.47, blue: 0.53, alpha: 1.0),
            type: NSColor(red: 0.56, green: 0.84, blue: 0.84, alpha: 1.0),
            function: NSColor(red: 0.40, green: 0.62, blue: 0.90, alpha: 1.0),
            property: NSColor(red: 0.84, green: 0.60, blue: 0.13, alpha: 1.0),
            operator: NSColor(red: 0.70, green: 0.70, blue: 0.76, alpha: 1.0),
            punctuation: NSColor(red: 0.60, green: 0.60, blue: 0.66, alpha: 1.0),
            preprocessor: NSColor(red: 0.75, green: 0.54, blue: 0.89, alpha: 1.0),
            error: NSColor(red: 1.0, green: 0.27, blue: 0.27, alpha: 1.0),
            plain: NSColor(red: 0.85, green: 0.85, blue: 0.87, alpha: 1.0)
        )
        #endif
    }()

    /// Light mode optimized color scheme
    public static let light: SyntaxColorScheme = {
        #if canImport(UIKit)
        return Self(
            keyword: UIColor(red: 0.68, green: 0.18, blue: 0.89, alpha: 1.0),
            identifier: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
            string: UIColor(red: 0.77, green: 0.10, blue: 0.09, alpha: 1.0),
            number: UIColor(red: 0.13, green: 0.43, blue: 0.85, alpha: 1.0),
            comment: UIColor(red: 0.42, green: 0.47, blue: 0.53, alpha: 1.0),
            type: UIColor(red: 0.0, green: 0.46, blue: 0.46, alpha: 1.0),
            function: UIColor(red: 0.0, green: 0.46, blue: 0.46, alpha: 1.0),
            property: UIColor(red: 0.50, green: 0.35, blue: 0.0, alpha: 1.0),
            operator: UIColor(red: 0.40, green: 0.40, blue: 0.40, alpha: 1.0),
            punctuation: UIColor(red: 0.50, green: 0.50, blue: 0.50, alpha: 1.0),
            preprocessor: UIColor(red: 0.63, green: 0.29, blue: 0.64, alpha: 1.0),
            error: UIColor(red: 0.86, green: 0.14, blue: 0.14, alpha: 1.0),
            plain: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        )
        #else
        return Self(
            keyword: NSColor(red: 0.68, green: 0.18, blue: 0.89, alpha: 1.0),
            identifier: NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
            string: NSColor(red: 0.77, green: 0.10, blue: 0.09, alpha: 1.0),
            number: NSColor(red: 0.13, green: 0.43, blue: 0.85, alpha: 1.0),
            comment: NSColor(red: 0.42, green: 0.47, blue: 0.53, alpha: 1.0),
            type: NSColor(red: 0.0, green: 0.46, blue: 0.46, alpha: 1.0),
            function: NSColor(red: 0.0, green: 0.46, blue: 0.46, alpha: 1.0),
            property: NSColor(red: 0.50, green: 0.35, blue: 0.0, alpha: 1.0),
            operator: NSColor(red: 0.40, green: 0.40, blue: 0.40, alpha: 1.0),
            punctuation: NSColor(red: 0.50, green: 0.50, blue: 0.50, alpha: 1.0),
            preprocessor: NSColor(red: 0.63, green: 0.29, blue: 0.64, alpha: 1.0),
            error: NSColor(red: 0.86, green: 0.14, blue: 0.14, alpha: 1.0),
            plain: NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        )
        #endif
    }()
}

extension SyntaxColorScheme {
    /// Resolve a high-level syntax token against this color scheme.
    public func color(for tokenType: TokenType) -> PlatformColor {
        switch tokenType {
        case .keyword:
            keyword

        case .identifier:
            identifier

        case .string:
            string

        case .number:
            number

        case .comment:
            comment

        case .type:
            type

        case .function:
            function

        case .property:
            property

        case .operator:
            self.operator

        case .punctuation:
            punctuation

        case .whitespace:
            plain.withAlphaComponent(0)

        case .preprocessor:
            preprocessor

        case .unknown:
            plain
        }
    }

    /// Resolve a regex token through the canonical high-level token mapping.
    public func color(for tokenType: RegexSyntaxTokenType) -> PlatformColor {
        color(for: TokenType(fromRegexType: tokenType))
    }

    /// Resolve a Swift parser token through the canonical high-level token mapping.
    public func color(for tokenType: SwiftTokenType) -> PlatformColor {
        color(for: TokenType(fromSwiftType: tokenType))
    }

    /// Resolve a high-level syntax token through an applied theme.
    public static func color(for tokenType: TokenType, in theme: Theme) -> PlatformColor {
        if tokenType == .whitespace {
            return PlatformColor(tokens: theme.color(forToken: tokenType.tokenName)).withAlphaComponent(0)
        }
        return color(forToken: tokenType.tokenName, in: theme)
    }

    /// Resolve a capture name through an applied theme, using dotted token
    /// fallback for unknown provider-specific captures.
    public static func color(forCapture capture: String, in theme: Theme) -> PlatformColor {
        if let tokenType = TokenType(rawValue: capture) {
            return color(for: tokenType, in: theme)
        }
        return color(forToken: TokenName(capture), in: theme)
    }

    /// Resolve a token-name to its themed `PlatformColor`. Routes through
    /// `Theme.color(forToken:)`, which performs hierarchical dotted
    /// fallback over `style.syntax` and ends at `style.editor.foreground`.
    /// This is the recommended entry point for any new syntax-highlight
    /// call site; the per-appearance baked schemes (`.default`, `.dark`,
    /// `.light`) are kept in place as transitional defaults for existing
    /// callers.
    public static func color(forToken token: TokenName, in theme: Theme) -> PlatformColor {
        PlatformColor(tokens: theme.color(forToken: token))
    }
}

// swiftlint:enable object_literal
