#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
import Foundation

// MARK: - AdaptiveColorSystem

/// Provides adaptive colors that work well with modern macOS designs
@MainActor
public enum AdaptiveColorSystem {
    // MARK: - Syntax Highlighting Colors

    /// Adaptive syntax highlighting colors
    public static func syntaxColor(for tokenType: TokenType) -> PlatformColor {
        // Use enhanced colors on macOS 14+ for better contrast
        if MacOSVersionDetection.isMacOS14OrLater {
            enhancedColor(for: tokenType)
        } else {
            traditionalColor(for: tokenType)
        }
    }

    // MARK: - Enhanced Colors (macOS 14+)

    private static func enhancedColor(for tokenType: TokenType) -> PlatformColor {
        switch tokenType {
        case .keyword:
            // Enhanced purple with better contrast
            PlatformColor(displayP3Red: 0.65, green: 0.31, blue: 0.85, alpha: 1.0)

        case .identifier:
            // Primary label color with enhanced contrast
            PlatformColors.label.withAlphaComponent(0.95)

        case .string:
            // Warmer red for better visibility
            PlatformColor(displayP3Red: 0.85, green: 0.25, blue: 0.30, alpha: 1.0)

        case .number:
            // Vivid blue
            PlatformColor(displayP3Red: 0.15, green: 0.45, blue: 0.90, alpha: 1.0)

        case .comment:
            // Softer green that maintains readability
            PlatformColor(displayP3Red: 0.25, green: 0.70, blue: 0.35, alpha: 0.85)

        case .type:
            // Enhanced teal
            PlatformColor(displayP3Red: 0.20, green: 0.65, blue: 0.75, alpha: 1.0)

        case .function:
            // Rich indigo
            PlatformColor(displayP3Red: 0.35, green: 0.25, blue: 0.80, alpha: 1.0)

        case .property:
            // Warm orange with improved contrast
            PlatformColor(displayP3Red: 0.90, green: 0.50, blue: 0.15, alpha: 1.0)

        case .operator:
            // Earth tone brown
            PlatformColor(displayP3Red: 0.65, green: 0.45, blue: 0.25, alpha: 1.0)

        case .punctuation:
            // Subtle but visible secondary color
            PlatformColors.secondaryLabel.withAlphaComponent(0.80)

        case .preprocessor:
            // Vibrant pink for preprocessor directives
            PlatformColor(displayP3Red: 0.85, green: 0.35, blue: 0.70, alpha: 1.0)

        case .whitespace:
            PlatformColors.clear

        case .unknown:
            PlatformColors.label
        }
    }

    // MARK: - Traditional Colors (macOS < 14)

    private static func traditionalColor(for tokenType: TokenType) -> PlatformColor {
        switch tokenType {
        case .keyword:
            PlatformColors.systemPurple

        case .identifier:
            PlatformColors.label

        case .string:
            PlatformColors.systemRed

        case .number:
            PlatformColors.systemBlue

        case .comment:
            PlatformColors.systemGreen

        case .type:
            PlatformColors.systemTeal

        case .function:
            PlatformColors.systemIndigo

        case .property:
            PlatformColors.systemOrange

        case .operator:
            PlatformColors.systemBrown

        case .punctuation:
            PlatformColors.secondaryLabel

        case .preprocessor:
            PlatformColors.systemPink

        case .whitespace:
            PlatformColors.clear

        case .unknown:
            PlatformColors.label
        }
    }

    // MARK: - UI Element Colors

    /// Adaptive background color for text editing areas
    public static var textBackgroundColor: PlatformColor {
        if MacOSVersionDetection.isMacOS14OrLater {
            // Use a slightly enhanced background for newer systems
            PlatformColors.textBackgroundColor.withAlphaComponent(0.98)
        } else {
            PlatformColors.textBackgroundColor
        }
    }

    /// Adaptive selection color
    public static var selectionColor: PlatformColor {
        if MacOSVersionDetection.isMacOS14OrLater {
            // Enhanced selection color for better visibility
            PlatformColors.selectedTextBackgroundColor.withAlphaComponent(0.90)
        } else {
            PlatformColors.selectedTextBackgroundColor
        }
    }

    /// Adaptive line number color
    public static var lineNumberColor: PlatformColor {
        if MacOSVersionDetection.isMacOS14OrLater {
            // Slightly enhanced line numbers
            PlatformColors.secondaryLabel.withAlphaComponent(0.75)
        } else {
            PlatformColors.secondaryLabel
        }
    }

    /// Adaptive gutter background color
    public static var gutterBackgroundColor: PlatformColor {
        if MacOSVersionDetection.isMacOS14OrLater {
            // Subtle gutter enhancement
            PlatformColors.controlBackground.withAlphaComponent(0.70)
        } else {
            PlatformColors.controlBackground
        }
    }

    // MARK: - Annotation Colors

    /// Get adaptive color for annotation types
    public static func annotationColor(for severity: AnnotationSeverity) -> PlatformColor {
        if MacOSVersionDetection.isMacOS14OrLater {
            switch severity {
            case .info:
                PlatformColors.systemBlue.withAlphaComponent(0.75)

            case .warning:
                PlatformColors.systemOrange.withAlphaComponent(0.80)

            case .error:
                PlatformColors.systemRed.withAlphaComponent(0.85)
            }
        } else {
            switch severity {
            case .info:
                PlatformColors.systemBlue.withAlphaComponent(0.60)

            case .warning:
                PlatformColors.systemOrange.withAlphaComponent(0.65)

            case .error:
                PlatformColors.systemRed.withAlphaComponent(0.70)
            }
        }
    }

    public enum AnnotationSeverity {
        case info
        case warning
        case error
    }
}

// MARK: - TokenType Extension
// Extension removed - adaptiveColor is already defined in TokenType enum
#endif
