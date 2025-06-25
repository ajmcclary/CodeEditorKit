#if canImport(AppKit)
import AppKit
import Foundation

// MARK: - AdaptiveColorSystem

/// Provides adaptive colors that work well with macOS 26's Liquid Glass design
@MainActor
public enum AdaptiveColorSystem {
    // MARK: - Syntax Highlighting Colors

    /// Adaptive syntax highlighting colors that work with Liquid Glass
    public static func syntaxColor(for tokenType: TokenType) -> NSColor {
        if MacOSVersionDetection.supportsLiquidGlassDesign {
            liquidGlassColor(for: tokenType)
        } else {
            traditionalColor(for: tokenType)
        }
    }

    // MARK: - Liquid Glass Colors (macOS 26+)

    private static func liquidGlassColor(for tokenType: TokenType) -> NSColor {
        switch tokenType {
        case .keyword:
            // Enhanced purple with better contrast for translucent surfaces
            NSColor(displayP3Red: 0.65, green: 0.31, blue: 0.85, alpha: 1.0)

        case .identifier:
            // Primary label color with enhanced contrast
            NSColor.labelColor.withAlphaComponent(0.95)

        case .string:
            // Warmer red that works well with Liquid Glass
            NSColor(displayP3Red: 0.85, green: 0.25, blue: 0.30, alpha: 1.0)

        case .number:
            // Vivid blue optimized for translucent backgrounds
            NSColor(displayP3Red: 0.15, green: 0.45, blue: 0.90, alpha: 1.0)

        case .comment:
            // Softer green that maintains readability
            NSColor(displayP3Red: 0.25, green: 0.70, blue: 0.35, alpha: 0.85)

        case .type:
            // Enhanced teal with better depth
            NSColor(displayP3Red: 0.20, green: 0.65, blue: 0.75, alpha: 1.0)

        case .function:
            // Rich indigo that works with glass materials
            NSColor(displayP3Red: 0.35, green: 0.25, blue: 0.80, alpha: 1.0)

        case .property:
            // Warm orange with improved contrast
            NSColor(displayP3Red: 0.90, green: 0.50, blue: 0.15, alpha: 1.0)

        case .operator:
            // Earth tone brown that complements Liquid Glass
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

    // MARK: - Traditional Colors (macOS < 26)

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
        if MacOSVersionDetection.supportsLiquidGlassDesign {
            // Use a slightly translucent background that works with Liquid Glass
            NSColor.textBackgroundColor.withAlphaComponent(0.95)
        } else {
            NSColor.textBackgroundColor
        }
    }

    /// Adaptive selection color
    public static var selectionColor: NSColor {
        if MacOSVersionDetection.supportsLiquidGlassDesign {
            // Enhanced selection color for better visibility on glass
            NSColor.selectedTextBackgroundColor.withAlphaComponent(0.85)
        } else {
            NSColor.selectedTextBackgroundColor
        }
    }

    /// Adaptive line number color
    public static var lineNumberColor: NSColor {
        if MacOSVersionDetection.supportsLiquidGlassDesign {
            // Softer line numbers that don't compete with glass effects
            NSColor.secondaryLabelColor.withAlphaComponent(0.70)
        } else {
            NSColor.secondaryLabelColor
        }
    }

    /// Adaptive gutter background color
    public static var gutterBackgroundColor: NSColor {
        if MacOSVersionDetection.supportsLiquidGlassDesign {
            // Subtle gutter that complements Liquid Glass
            NSColor.controlBackgroundColor.withAlphaComponent(0.60)
        } else {
            NSColor.controlBackgroundColor
        }
    }

    // MARK: - Annotation Colors

    /// Get adaptive color for annotation types
    public static func annotationColor(for severity: AnnotationSeverity) -> NSColor {
        if MacOSVersionDetection.supportsLiquidGlassDesign {
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
