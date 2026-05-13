import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - TextKit Capabilities

extension PlatformCapabilities {
    /// TextKit version and feature support
    public struct TextKitCapabilities {
        /// Whether the required TextKit2 surface is available.
        public let supportsRequiredTextKit2Surface: Bool

        /// Whether TextKit 2 layout fragments are supported
        public let supportsTextLayoutFragments: Bool

        /// Whether advanced rendering attributes are supported
        public let supportsRenderingAttributes: Bool
    }

    /// Get comprehensive TextKit capabilities
    ///
    /// This computed property provides a complete overview of TextKit support
    /// on the current platform, allowing for informed decisions about which
    /// text rendering features to enable.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let textKit = capabilities.textKitCapabilities
    /// if textKit.supportsRequiredTextKit2Surface {
    ///     // Use modern TextKit2 features
    /// }
    /// ```
    ///
    /// - Returns: Comprehensive TextKit capability information
    public var textKitCapabilities: TextKitCapabilities {
        TextKitCapabilities(
            supportsRequiredTextKit2Surface: supportsRequiredTextKit2Surface,
            supportsTextLayoutFragments: supportsTextLayoutFragments,
            supportsRenderingAttributes: supportsRenderingAttributes
        )
    }

    /// Whether the required TextKit2 surface is supported on this platform.
    public var supportsRequiredTextKit2Surface: Bool {
        #if canImport(AppKit)
        let (major, minor, _) = systemVersionComponents
        return major > 13 || (major == 13 && minor >= 0)
        #elseif canImport(UIKit)
        let (major, minor, _) = systemVersionComponents
        return major > 16 || (major == 16 && minor >= 0)
        #else
        return false
        #endif
    }

    /// Whether TextKit2 text layout fragments are supported
    ///
    /// Text layout fragments provide improved performance for large documents
    /// and better control over text rendering.
    ///
    /// - Returns: True if layout fragments are available
    public var supportsTextLayoutFragments: Bool {
        supportsRequiredTextKit2Surface
    }

    /// Whether TextKit2 rendering attributes are supported
    ///
    /// Advanced rendering attributes allow for more sophisticated text
    /// styling and effects.
    ///
    /// - Returns: True if advanced rendering attributes are available
    public var supportsRenderingAttributes: Bool {
        supportsRequiredTextKit2Surface
    }

    /// Get recommended TextKit configuration for optimal performance
    ///
    /// This method provides platform-specific recommendations for TextKit
    /// configuration based on system capabilities and performance characteristics.
    ///
    /// ## Configuration Options
    /// - **enableLayoutFragments**: Whether to use layout fragments
    /// - **maxRenderingLength**: Maximum document length for full rendering
    /// - **incrementalRendering**: Whether to use incremental updates
    ///
    /// - Returns: Recommended TextKit configuration
    public func recommendedTextKitConfiguration() -> TextKitConfiguration {
        var config = TextKitConfiguration()

        config.enableLayoutFragments = supportsTextLayoutFragments

        // Performance tuning based on platform
        switch currentPlatform {
        case .macOS:
            config.maxRenderingLength = 1_000_000 // 1MB
            config.incrementalRendering = true
            config.enableBackgroundParsing = true

        case .iOS:
            // More conservative on iOS
            config.maxRenderingLength = 500_000 // 500KB
            config.incrementalRendering = true
            config.enableBackgroundParsing = supportsBackgroundProcessing
        }

        // Memory-based adjustments
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        if physicalMemory < 4 * 1_024 * 1_024 * 1_024 { // < 4GB
            config.maxRenderingLength /= 2
            config.enableBackgroundParsing = false
        }

        return config
    }

    /// Configuration for TextKit features and performance
    public struct TextKitConfiguration {
        /// Whether to enable TextKit2 layout fragments
        public var enableLayoutFragments: Bool = false

        /// Maximum document length for full syntax highlighting
        public var maxRenderingLength: Int = 500_000

        /// Whether to use incremental rendering updates
        public var incrementalRendering: Bool = true

        /// Whether to enable background text parsing
        public var enableBackgroundParsing: Bool = true

        /// Creates default text rendering optimization settings
        public init() {}
    }
}
