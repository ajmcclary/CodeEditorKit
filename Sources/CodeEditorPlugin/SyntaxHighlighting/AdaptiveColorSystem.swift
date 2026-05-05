#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
import Foundation

// MARK: - AdaptiveColorSystem

/// Provides adaptive colors that work well with modern macOS designs
@MainActor
public enum AdaptiveColorSystem {
    // MARK: - Syntax Highlighting Colors

    /// Adaptive syntax highlighting colors
    /// - Parameters:
    ///   - tokenType: The type of syntax token to color
    ///   - capabilities: Platform capabilities for adaptive behavior (defaults to dependency factory)
    public static func syntaxColor(
        for tokenType: TokenType,
        capabilities: PlatformCapabilities? = nil
    ) -> PlatformColor {
        let capabilities = capabilities ?? CodeEditorDependencies.makePlatformCapabilities()
        // Use enhanced colors on macOS 14+ for better contrast
        if capabilities.currentPlatform == .macOS && capabilities.systemVersionComponents.major >= 14 {
            return enhancedColor(for: tokenType)
        } else {
            return traditionalColor(for: tokenType)
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
        textBackgroundColor(capabilities: CodeEditorDependencies.makePlatformCapabilities())
    }

    /// Adaptive background color for text editing areas with injectable capabilities
    public static func textBackgroundColor(capabilities: PlatformCapabilities) -> PlatformColor {
        if capabilities.currentPlatform == .macOS && capabilities.systemVersionComponents.major >= 14 {
            // Use a slightly enhanced background for newer systems
            PlatformColors.textBackgroundColor.withAlphaComponent(0.98)
        } else {
            PlatformColors.textBackgroundColor
        }
    }

    /// Adaptive selection color
    public static var selectionColor: PlatformColor {
        selectionColor(capabilities: CodeEditorDependencies.makePlatformCapabilities())
    }

    /// Adaptive selection color with injectable capabilities
    public static func selectionColor(capabilities: PlatformCapabilities) -> PlatformColor {
        if capabilities.currentPlatform == .macOS && capabilities.systemVersionComponents.major >= 14 {
            // Enhanced selection color for better visibility
            PlatformColors.selectedTextBackgroundColor.withAlphaComponent(0.90)
        } else {
            PlatformColors.selectedTextBackgroundColor
        }
    }

    /// Adaptive line number color
    public static var lineNumberColor: PlatformColor {
        lineNumberColor(capabilities: CodeEditorDependencies.makePlatformCapabilities())
    }

    /// Adaptive line number color with injectable capabilities
    public static func lineNumberColor(capabilities: PlatformCapabilities) -> PlatformColor {
        if capabilities.currentPlatform == .macOS && capabilities.systemVersionComponents.major >= 14 {
            // Slightly enhanced line numbers
            PlatformColors.secondaryLabel.withAlphaComponent(0.75)
        } else {
            PlatformColors.secondaryLabel
        }
    }

    /// Adaptive gutter background color
    public static var gutterBackgroundColor: PlatformColor {
        gutterBackgroundColor(capabilities: CodeEditorDependencies.makePlatformCapabilities())
    }

    /// Adaptive gutter background color with injectable capabilities
    public static func gutterBackgroundColor(capabilities: PlatformCapabilities) -> PlatformColor {
        if capabilities.currentPlatform == .macOS && capabilities.systemVersionComponents.major >= 14 {
            // Subtle gutter enhancement
            PlatformColors.controlBackground.withAlphaComponent(0.70)
        } else {
            PlatformColors.controlBackground
        }
    }

    // MARK: - Annotation Colors

    /// Get adaptive color for annotation types
    /// - Parameters:
    ///   - severity: The severity level of the annotation
    ///   - capabilities: Platform capabilities for adaptive behavior (defaults to dependency factory)
    public static func annotationColor(
        for severity: AnnotationSeverity,
        capabilities: PlatformCapabilities? = nil
    ) -> PlatformColor {
        let capabilities = capabilities ?? CodeEditorDependencies.makePlatformCapabilities()
        if capabilities.currentPlatform == .macOS && capabilities.systemVersionComponents.major >= 14 {
            switch severity {
            case .info:
                return PlatformColors.systemBlue.withAlphaComponent(0.75)

            case .warning:
                return PlatformColors.systemOrange.withAlphaComponent(0.80)

            case .error:
                return PlatformColors.systemRed.withAlphaComponent(0.85)
            }
        } else {
            switch severity {
            case .info:
                return PlatformColors.systemBlue.withAlphaComponent(0.60)

            case .warning:
                return PlatformColors.systemOrange.withAlphaComponent(0.65)

            case .error:
                return PlatformColors.systemRed.withAlphaComponent(0.70)
            }
        }
    }

    /// Represents the severity level of code annotations for adaptive color selection
    ///
    /// Used by the adaptive color system to determine appropriate colors for different
    /// types of code annotations, diagnostics, and user feedback elements.
    public enum AnnotationSeverity {
        /// Informational annotation level
        ///
        /// Used for general information, hints, or non-critical notifications
        /// that don't require immediate attention.
        case info

        /// Warning annotation level
        ///
        /// Used for potential issues, deprecated usage, or situations that
        /// may cause problems but don't prevent code execution.
        case warning

        /// Error annotation level
        ///
        /// Used for critical issues, compilation errors, or problems that
        /// prevent proper code execution and require immediate attention.
        case error
    }
}

// MARK: - TokenType Extension
// Extension removed - adaptiveColor is already defined in TokenType enum
#endif
