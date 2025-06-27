#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
import Foundation

// MARK: - AdaptiveColorSystem

/// Provides adaptive colors that work well with modern macOS designs
@MainActor
public enum AdaptiveColorSystem {
    // MARK: - Syntax Highlighting Colors

    /// Adaptive syntax highlighting colors
    public static func syntaxColor(for tokenType: TokenType) -> NSColor {
        // Use enhanced colors on macOS 14+ for better contrast
        if MacOSVersionDetection.isMacOS14OrLater {
            enhancedColor(for: tokenType)
        } else {
            traditionalColor(for: tokenType)
        }
    }

    // MARK: - Enhanced Colors (macOS 14+)

    private static func enhancedColor(for tokenType: TokenType) -> NSColor {
        switch tokenType {
        case .keyword:
            // Enhanced purple with better contrast
            NSColor(displayP3Red: 0.65, green: 0.31, blue: 0.85, alpha: 1.0)

        case .identifier:
            // Primary label color with enhanced contrast
            NSColor.labelColor.withAlphaComponent(0.95)

        case .string:
            // Warmer red for better visibility
            NSColor(displayP3Red: 0.85, green: 0.25, blue: 0.30, alpha: 1.0)

        case .number:
            // Vivid blue
            NSColor(displayP3Red: 0.15, green: 0.45, blue: 0.90, alpha: 1.0)

        case .comment:
            // Softer green that maintains readability
            NSColor(displayP3Red: 0.25, green: 0.70, blue: 0.35, alpha: 0.85)

        case .type:
            // Enhanced teal
            NSColor(displayP3Red: 0.20, green: 0.65, blue: 0.75, alpha: 1.0)

        case .function:
            // Rich indigo
            NSColor(displayP3Red: 0.35, green: 0.25, blue: 0.80, alpha: 1.0)

        case .property:
            // Warm orange with improved contrast
            NSColor(displayP3Red: 0.90, green: 0.50, blue: 0.15, alpha: 1.0)

        case .operator:
            // Earth tone brown
            NSColor(displayP3Red: 0.65, green: 0.45, blue: 0.25, alpha: 1.0)

        case .punctuation:
            // Subtle but visible secondary color
            NSColor.secondaryLabelColor.withAlphaComponent(0.80)

        case .preprocessor:
            // Vibrant pink for preprocessor directives
            NSColor(displayP3Red: 0.85, green: 0.35, blue: 0.70, alpha: 1.0)

        case .whitespace:
            NSColor.clear

        case .unknown:
            NSColor.labelColor
        }
    }

    // MARK: - Traditional Colors (macOS < 14)

    private static func traditionalColor(for tokenType: TokenType) -> NSColor {
        switch tokenType {
        case .keyword:
            NSColor.systemPurple

        case .identifier:
            NSColor.labelColor

        case .string:
            NSColor.systemRed

        case .number:
            NSColor.systemBlue

        case .comment:
            NSColor.systemGreen

        case .type:
            NSColor.systemTeal

        case .function:
            NSColor.systemIndigo

        case .property:
            NSColor.systemOrange

        case .operator:
            NSColor.systemBrown

        case .punctuation:
            NSColor.secondaryLabelColor

        case .preprocessor:
            NSColor.systemPink

        case .whitespace:
            NSColor.clear

        case .unknown:
            NSColor.labelColor
        }
    }

    // MARK: - UI Element Colors

    /// Adaptive background color for text editing areas
    public static var textBackgroundColor: NSColor {
        if MacOSVersionDetection.isMacOS14OrLater {
            // Use a slightly enhanced background for newer systems
            NSColor.textBackgroundColor.withAlphaComponent(0.98)
        } else {
            NSColor.textBackgroundColor
        }
    }

    /// Adaptive selection color
    public static var selectionColor: NSColor {
        if MacOSVersionDetection.isMacOS14OrLater {
            // Enhanced selection color for better visibility
            NSColor.selectedTextBackgroundColor.withAlphaComponent(0.90)
        } else {
            NSColor.selectedTextBackgroundColor
        }
    }

    /// Adaptive line number color
    public static var lineNumberColor: NSColor {
        if MacOSVersionDetection.isMacOS14OrLater {
            // Slightly enhanced line numbers
            NSColor.secondaryLabelColor.withAlphaComponent(0.75)
        } else {
            NSColor.secondaryLabelColor
        }
    }

    /// Adaptive gutter background color
    public static var gutterBackgroundColor: NSColor {
        if MacOSVersionDetection.isMacOS14OrLater {
            // Subtle gutter enhancement
            NSColor.controlBackgroundColor.withAlphaComponent(0.70)
        } else {
            NSColor.controlBackgroundColor
        }
    }

    // MARK: - Annotation Colors

    /// Get adaptive color for annotation types
    public static func annotationColor(for severity: AnnotationSeverity) -> NSColor {
        if MacOSVersionDetection.isMacOS14OrLater {
            switch severity {
            case .info:
                NSColor.systemBlue.withAlphaComponent(0.75)

            case .warning:
                NSColor.systemOrange.withAlphaComponent(0.80)

            case .error:
                NSColor.systemRed.withAlphaComponent(0.85)
            }
        } else {
            switch severity {
            case .info:
                NSColor.systemBlue.withAlphaComponent(0.60)

            case .warning:
                NSColor.systemOrange.withAlphaComponent(0.65)

            case .error:
                NSColor.systemRed.withAlphaComponent(0.70)
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
