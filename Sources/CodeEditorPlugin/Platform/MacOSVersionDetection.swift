#if canImport(AppKit)
import AppKit
import Foundation

// MARK: - MacOSVersionDetection

/// Utility for detecting macOS version and enabling version-specific features
@MainActor
public enum MacOSVersionDetection {
    // MARK: - Version Detection
    
    /// Get the current macOS version components
    public static var versionComponents: (major: Int, minor: Int, patch: Int) {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return (version.majorVersion, version.minorVersion, version.patchVersion)
    }
    
    /// Check if running on macOS 14 (Sonoma) or later
    public static var isMacOS14OrLater: Bool {
        if #available(macOS 14.0, *) {
            return true
        }
        return false
    }
    
    /// Check if running on macOS 13 (Ventura) or later
    public static var isMacOS13OrLater: Bool {
        if #available(macOS 13.0, *) {
            return true
        }
        return false
    }
    
    /// Check if running on macOS 12 (Monterey) or later
    public static var isMacOS12OrLater: Bool {
        if #available(macOS 12.0, *) {
            return true
        }
        return false
    }
    
    // MARK: - Feature Detection
    
    /// Check if TextKit2 is stable and should be preferred
    public static var hasStableTextKit2: Bool {
        // TextKit2 is stable on macOS 13.0+
        isMacOS13OrLater
    }
    
    /// Check if the system prefers TextKit2
    public static var prefersTextKit2: Bool {
        // Prefer TextKit2 on macOS 14.0+ for better stability
        isMacOS14OrLater
    }
    
    /// Check if CADisplayLink is available
    public static var supportsCADisplayLink: Bool {
        // CADisplayLink is available on macOS 14.0+
        isMacOS14OrLater
    }
    
    /// Check if enhanced control sizes are available
    public static var supportsEnhancedControlSizes: Bool {
        // Enhanced control sizes came with macOS 13.0
        isMacOS13OrLater
    }
    
    // MARK: - Control Size Utilities
    
    /// Get the appropriate control size for the current macOS version
    public static func recommendedControlSize(for priority: ControlPriority) -> NSControl.ControlSize {
        switch priority {
        case .primary:
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
    
    // MARK: - System Information
    
    /// Get system version info as string
    public static var systemVersionString: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
    
    /// Get the marketing name of the current macOS version
    public static var systemMarketingName: String {
        let major = versionComponents.major
        switch major {
        case 14: return "macOS Sonoma"
        case 13: return "macOS Ventura"
        case 12: return "macOS Monterey"
        case 11: return "macOS Big Sur"
        case 10: return "macOS Catalina" // 10.15
        default: return "macOS \(major)"
        }
    }
}

// MARK: - NSControl.ControlSize Extensions

extension NSControl.ControlSize {
    /// Get the recommended height for this control size
    @MainActor var recommendedHeight: CGFloat {
        switch self {
        case .mini:
            return 16.0
            
        case .small:
            return 22.0
            
        case .regular:
            return 28.0
            
        case .large:
            return 32.0
            
        @unknown default:
            return 28.0
        }
    }
}

#else
// MARK: - IOS/UIKit Stub

import Foundation

/// Stub implementation for iOS
@MainActor
public enum MacOSVersionDetection {
    public static var versionComponents: (major: Int, minor: Int, patch: Int) {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return (version.majorVersion, version.minorVersion, version.patchVersion)
    }
    
    public static var hasStableTextKit2: Bool {
        // TextKit2 is available on iOS 16.0+
        versionComponents.major >= 16
    }
    
    public static var prefersTextKit2: Bool {
        hasStableTextKit2
    }
    
    public static var isMacOS14OrLater: Bool { false }
    public static var isMacOS13OrLater: Bool { false }
    public static var isMacOS12OrLater: Bool { false }
    public static var supportsCADisplayLink: Bool { true } // Always available on iOS
    public static var supportsEnhancedControlSizes: Bool { false }
    
    public static var systemVersionString: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
    
    public enum ControlPriority {
        case primary
        case secondary
        case tertiary
    }
}
#endif
