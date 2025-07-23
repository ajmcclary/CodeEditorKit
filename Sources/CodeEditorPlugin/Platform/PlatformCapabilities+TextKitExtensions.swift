import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - TextKit Capabilities

extension PlatformCapabilities {
    /// TextKit version and feature support
    public struct TextKitCapabilities {
        public let supportsTextKit2: Bool
        public let preferTextKit2: Bool
        public let supportsTextLayoutFragments: Bool
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
    /// if textKit.preferTextKit2 {
    ///     // Use modern TextKit2 features
    ///     textView.useTextKit2 = true
    /// } else if textKit.supportsTextKit2 {
    ///     // TextKit2 available but not preferred
    ///     textView.useTextKit2 = userPreferences.experimentalFeatures
    /// }
    /// ```
    ///
    /// - Returns: Comprehensive TextKit capability information
    public var textKitCapabilities: TextKitCapabilities {
        TextKitCapabilities(
            supportsTextKit2: supportsTextKit2,
            preferTextKit2: preferTextKit2,
            supportsTextLayoutFragments: supportsTextLayoutFragments,
            supportsRenderingAttributes: supportsRenderingAttributes
        )
    }

    /// Whether TextKit2 is supported on the current platform
    ///
    /// TextKit2 provides improved performance and features but requires
    /// minimum OS versions for stability.
    ///
    /// ## Platform Support
    /// - **macOS**: Supported on 13.0+, stable on 14.0+
    /// - **iOS**: Supported on 16.0+
    /// - **Mac Catalyst**: Follows iOS requirements
    ///
    /// - Returns: True if TextKit2 is available
    public var supportsTextKit2: Bool {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // TextKit2 is stable on macOS 13.0+
        let (major, minor, _) = systemVersionComponents
        return major > 13 || (major == 13 && minor >= 0)
        #elseif canImport(UIKit)
        // TextKit2 is available on iOS 16.0+
        let (major, minor, _) = systemVersionComponents
        return major > 16 || (major == 16 && minor >= 0)
        #else
        return false
        #endif
    }

    /// Whether TextKit2 is preferred over TextKit1
    ///
    /// While TextKit2 may be supported, it might not be recommended
    /// for all use cases due to stability or feature completeness.
    ///
    /// ## Recommendation Logic
    /// - **macOS**: Preferred on 14.0+ for better stability
    /// - **iOS**: Always preferred when available
    /// - **Catalyst**: Follows iOS logic
    ///
    /// - Returns: True if TextKit2 should be used by default
    public var preferTextKit2: Bool {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // Prefer TextKit2 on macOS 14.0+ for better stability
        let (major, minor, _) = systemVersionComponents
        return major > 14 || (major == 14 && minor >= 0)
        #elseif canImport(UIKit)
        // Always prefer TextKit2 on iOS when available
        return supportsTextKit2
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
        supportsTextKit2
    }

    /// Whether TextKit2 rendering attributes are supported
    ///
    /// Advanced rendering attributes allow for more sophisticated text
    /// styling and effects.
    ///
    /// - Returns: True if advanced rendering attributes are available
    public var supportsRenderingAttributes: Bool {
        supportsTextKit2
    }

    /// Get recommended TextKit configuration for optimal performance
    ///
    /// This method provides platform-specific recommendations for TextKit
    /// configuration based on system capabilities and performance characteristics.
    ///
    /// ## Configuration Options
    /// - **useTextKit2**: Whether to enable TextKit2
    /// - **enableLayoutFragments**: Whether to use layout fragments
    /// - **maxRenderingLength**: Maximum document length for full rendering
    /// - **incrementalRendering**: Whether to use incremental updates
    ///
    /// - Returns: Recommended TextKit configuration
    public func recommendedTextKitConfiguration() -> TextKitConfiguration {
        var config = TextKitConfiguration()

        // Base TextKit version decision
        config.useTextKit2 = preferTextKit2
        config.enableLayoutFragments = supportsTextLayoutFragments && preferTextKit2

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

        case .catalyst:
            // Balanced approach for Catalyst
            config.maxRenderingLength = 750_000 // 750KB
            config.incrementalRendering = true
            config.enableBackgroundParsing = true
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
        /// Whether to use TextKit2 instead of TextKit1
        public var useTextKit2: Bool = false

        /// Whether to enable TextKit2 layout fragments
        public var enableLayoutFragments: Bool = false

        /// Maximum document length for full syntax highlighting
        public var maxRenderingLength: Int = 500_000

        /// Whether to use incremental rendering updates
        public var incrementalRendering: Bool = true

        /// Whether to enable background text parsing
        public var enableBackgroundParsing: Bool = true

        public init() {}
    }
}
