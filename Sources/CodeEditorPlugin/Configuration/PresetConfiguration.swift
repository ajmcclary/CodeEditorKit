import Foundation

// MARK: - Preset Configuration Enumeration

/// Enumeration of available preset configurations for the code editor
///
/// This enum provides type-safe access to predefined configurations that are
/// optimized for different use cases and platforms.
public enum PresetConfiguration: String, CaseIterable, Sendable {
    /// Default configuration with standard settings
    case `default` = "default"

    /// Minimal configuration for lightweight editing
    case minimal = "minimal"

    /// Read-only configuration for viewing code
    case readOnly = "readOnly"

    /// Configuration optimized for Markdown editing
    case markdown = "markdown"

    /// Configuration for presentation/demo mode
    case presentation = "presentation"

    /// Configuration optimized for iOS devices
    case iOS = "iOS"

    /// Configuration optimized for Mac Catalyst
    case catalyst = "catalyst"

    /// Configuration optimized for macOS
    case macOS = "macOS"

    /// Automatically selects the best configuration for the current platform
    case platformOptimized = "platformOptimized"

    /// Human-readable description of the preset
    public var description: String {
        switch self {
        case .default:
            return "Default configuration with standard settings"

        case .minimal:
            return "Minimal configuration for lightweight editing"

        case .readOnly:
            return "Read-only configuration for viewing code"

        case .markdown:
            return "Configuration optimized for Markdown editing"

        case .presentation:
            return "Configuration for presentation/demo mode"

        case .iOS:
            return "Configuration optimized for iOS devices"

        case .catalyst:
            return "Configuration optimized for Mac Catalyst"

        case .macOS:
            return "Configuration optimized for macOS"

        case .platformOptimized:
            return "Platform-optimized configuration"
        }
    }
}
