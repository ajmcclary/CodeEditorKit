#if canImport(AppKit)
import AppKit
import Foundation

// MARK: - MacOSVersionDetection

/// Utility for detecting macOS version and enabling version-specific features
@MainActor
public enum MacOSVersionDetection {
    // MARK: - Version Detection

    /// Check if running on macOS 26 (Tahoe) or later
    public static var isMacOS26OrLater: Bool {
        if #available(macOS 26.0, *) {
            return true
        }
        return false
    }

    /// Check if running on macOS 25 or later
    public static var isMacOS25OrLater: Bool {
        if #available(macOS 25.0, *) {
            return true
        }
        return false
    }

    /// Check if running on macOS 24 or later
    public static var isMacOS24OrLater: Bool {
        if #available(macOS 24.0, *) {
            return true
        }
        return false
    }

    /// Check if running on macOS 23 (Ventura) or later
    public static var isMacOS23OrLater: Bool {
        if #available(macOS 23.0, *) {
            return true
        }
        return false
    }

    // MARK: - Feature Detection

    /// Check if Liquid Glass design features are available
    public static var supportsLiquidGlassDesign: Bool {
        isMacOS26OrLater
    }

    /// Check if extra large control size is available
    public static var supportsExtraLargeControlSize: Bool {
        isMacOS26OrLater
    }

    /// Check if NSView.LayoutRegion API is available
    public static var supportsLayoutRegionAPI: Bool {
        isMacOS26OrLater
    }

    /// Check if NSTextView sound attachment support is available
    public static var supportsTextViewSoundAttachments: Bool {
        isMacOS26OrLater
    }

    /// Check if TextKit2 is default and stable
    public static var hasStableTextKit2: Bool {
        isMacOS23OrLater
    }

    // MARK: - Control Size Utilities

    /// Get the appropriate control size for the current macOS version
    public static func recommendedControlSize(for priority: ControlPriority) -> NSControl.ControlSize {
        switch priority {
        case .primary:
            if supportsExtraLargeControlSize {
                // Use extra large for primary actions on macOS 26+
                return .large // Using .large as placeholder since .extraLarge might not be available yet
            }
            return .large

        case .secondary:
            return .regular

        case .tertiary:
            return .small
        }
    }

    /// Control priority levels for sizing
    public enum ControlPriority {
        case primary // Most important actions
        case secondary // Standard actions
        case tertiary // Less important actions
    }

    // MARK: - Color System

    /// Check if we should use adapted colors for Liquid Glass design
    public static var shouldUseAdaptedColors: Bool {
        supportsLiquidGlassDesign
    }

    /// Get system version info as string
    public static var systemVersionString: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
}

// MARK: - NSControl.ControlSize Extensions

extension NSControl.ControlSize {
    /// Get the recommended height for this control size on current macOS version
    @MainActor var recommendedHeight: CGFloat {
        if MacOSVersionDetection.isMacOS26OrLater {
            // macOS 26+ has taller controls for better touch targets
            switch self {
            case .mini:
                return 18.0 // Increased from ~16
            case .small:
                return 24.0 // Increased from ~22
            case .regular:
                return 30.0 // Increased from ~28
            case .large:
                return 36.0 // Increased from ~32
            case .extraLarge:
                return 42.0 // New size for very large controls
            @unknown default:
                return 30.0
            }
        } else {
            // Legacy heights for older macOS versions
            switch self {
            case .mini:
                return 16.0

            case .small:
                return 22.0

            case .regular:
                return 28.0

            case .large:
                return 32.0

            case .extraLarge:
                return 38.0

            @unknown default:
                return 28.0
            }
        }
    }
}

#else
// MARK: iOS/UIKit Stub

/// Stub implementation for iOS
@MainActor
public enum MacOSVersionDetection {
    public static var hasStableTextKit2: Bool { false }
    public static var isMacOS26OrLater: Bool { false }
    public static var isMacOS25OrLater: Bool { false }
    public static var isMacOS24OrLater: Bool { false }
    public static var supportsTextViewSoundAttachments: Bool { false }
    public static var supportsLiquidGlassDesign: Bool { false }
    public static var supportsLayoutRegionAPI: Bool { false }
    public static var supportsExtraLargeControlSize: Bool { false }
}
#endif
