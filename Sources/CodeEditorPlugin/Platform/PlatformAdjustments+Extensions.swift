import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

/// Platform-specific adjustments for optimal user experience
///
/// Provides centralized configuration for platform-specific values like font sizes,
/// spacing, and performance limits. These adjustments ensure the editor provides
/// an optimal experience on each platform.
public struct PlatformAdjustments: Sendable {
    // MARK: - Font Adjustments

    /// Default font size for the platform
    public let defaultFontSize: CGFloat

    // MARK: - Spacing Adjustments

    /// Line spacing multiplier
    public let lineSpacing: CGFloat

    /// Width of the line number gutter
    public let gutterWidth: CGFloat

    // MARK: - Touch Adjustments

    /// Minimum size for touch targets
    public let minimumTouchTargetSize: CGFloat

    // MARK: - Performance Adjustments

    /// Maximum file size to process (in bytes)
    public let maxFileSize: Int

    /// Maximum text length for syntax highlighting
    public let maxSyntaxHighlightingLength: Int

    // MARK: - UI Adjustments

    /// Whether to show the minimap
    public let showMinimap: Bool

    /// Whether to enable multi-cursor editing
    public let enableMultiCursor: Bool

    // MARK: - Initialization

    /// Create default platform adjustments
    public init() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS adjustments
        self.defaultFontSize = 12.0
        self.lineSpacing = 1.2
        self.gutterWidth = 40.0
        self.minimumTouchTargetSize = 24.0
        self.maxFileSize = 10_000_000 // 10MB
        self.maxSyntaxHighlightingLength = 1_000_000
        self.showMinimap = true
        self.enableMultiCursor = true
        #else
        // iOS/Catalyst adjustments
        self.defaultFontSize = 14.0 // Larger for touch
        self.lineSpacing = 1.4 // More spacing for touch
        self.gutterWidth = 50.0 // Wider for touch targets
        self.minimumTouchTargetSize = 44.0 // iOS HIG recommendation
        self.maxFileSize = 5_000_000 // 5MB for iOS
        self.maxSyntaxHighlightingLength = 500_000 // Less for iOS
        self.showMinimap = false // Not supported on iOS
        self.enableMultiCursor = false // Simplified for iOS
        #endif
    }

    /// Create custom platform adjustments
    public init(
        defaultFontSize: CGFloat,
        lineSpacing: CGFloat,
        gutterWidth: CGFloat,
        minimumTouchTargetSize: CGFloat,
        maxFileSize: Int,
        maxSyntaxHighlightingLength: Int,
        showMinimap: Bool,
        enableMultiCursor: Bool
    ) {
        self.defaultFontSize = defaultFontSize
        self.lineSpacing = lineSpacing
        self.gutterWidth = gutterWidth
        self.minimumTouchTargetSize = minimumTouchTargetSize
        self.maxFileSize = maxFileSize
        self.maxSyntaxHighlightingLength = maxSyntaxHighlightingLength
        self.showMinimap = showMinimap
        self.enableMultiCursor = enableMultiCursor
    }

    // MARK: - Device-Specific Adjustments

    /// Create adjustments optimized for the current device
    @MainActor
    public static func forCurrentDevice() -> Self {
        let adjustments = Self()

        #if canImport(UIKit)
        // Further customize for specific iOS devices
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad can handle more
            return Self(
                defaultFontSize: adjustments.defaultFontSize,
                lineSpacing: adjustments.lineSpacing,
                gutterWidth: adjustments.gutterWidth,
                minimumTouchTargetSize: 44.0,
                maxFileSize: 8_000_000, // 8MB for iPad
                maxSyntaxHighlightingLength: 750_000,
                showMinimap: UIDevice.current.userInterfaceIdiom == .pad && UIScreen.main.bounds.width > 1_000,
                enableMultiCursor: false
            )
        } else if UIDevice.current.userInterfaceIdiom == .phone {
            // iPhone needs more conservative settings
            return Self(
                defaultFontSize: 13.0, // Slightly smaller for phones
                lineSpacing: 1.3,
                gutterWidth: 35.0, // Narrower for phones
                minimumTouchTargetSize: 44.0,
                maxFileSize: 3_000_000, // 3MB for iPhone
                maxSyntaxHighlightingLength: 250_000,
                showMinimap: false,
                enableMultiCursor: false
            )
        }
        #endif

        return adjustments
    }
}

// MARK: - Extensions

extension PlatformAdjustments {
    /// Apply these adjustments to an editor configuration
    public func apply(to configuration: inout EditorConfiguration) {
        configuration.display.fontSize = defaultFontSize
        configuration.layout.lineHeightMultiple = lineSpacing
        configuration.layout.gutterWidth = gutterWidth
        configuration.display.showMinimap = showMinimap
        configuration.performance.maxSyntaxHighlightingLength = maxSyntaxHighlightingLength
        // Only apply maxFileSize if not already configured (0 means use platform default)
        if configuration.performance.maxFileSize == 0 {
            configuration.performance.maxFileSize = maxFileSize
        }
    }
}
