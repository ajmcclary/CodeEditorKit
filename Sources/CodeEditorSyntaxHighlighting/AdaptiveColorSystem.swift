import CodeEditorPlatform
#if canImport(AppKit)
import AppKit
import Foundation

// MARK: - AdaptiveColorSystem

/// Provides adaptive colors that work well with modern macOS designs
@MainActor
public enum AdaptiveColorSystem {
    // MARK: - Syntax Highlighting Colors

    /// Syntax highlighting colors routed through the canonical scheme.
    /// - Parameters:
    ///   - tokenType: The type of syntax token to color
    ///   - capabilities: Platform capabilities for adaptive behavior (defaults to dependency factory)
    public static func syntaxColor(
        for tokenType: TokenType,
        capabilities: PlatformCapabilities? = nil
    ) -> PlatformColor {
        _ = capabilities
        return SyntaxColorScheme.default.color(for: tokenType)
    }

    // MARK: - UI Element Colors

    /// Adaptive background color for text editing areas
    public static var textBackgroundColor: PlatformColor {
        textBackgroundColor(capabilities: PlatformCapabilities())
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
        selectionColor(capabilities: PlatformCapabilities())
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
        lineNumberColor(capabilities: PlatformCapabilities())
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
        gutterBackgroundColor(capabilities: PlatformCapabilities())
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
        let capabilities = capabilities ?? PlatformCapabilities()
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
