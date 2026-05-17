import Foundation
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

// MARK: - Cross-Platform Font Helpers

/// Cross-platform font utilities that provide consistent font creation
/// across macOS and iOS platforms.
/// 
/// This enum provides static methods for creating commonly used fonts
/// with appropriate platform-specific implementations.
public enum PlatformFonts {
    /// Creates a monospaced system font with the specified size and weight
    public static func monospacedSystemFont(ofSize size: CGFloat, weight: PlatformFont.Weight = .regular) -> PlatformFont {
        #if canImport(AppKit)
        return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        #else
        return UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        #endif
    }

    /// Creates a system font with the specified size and weight
    public static func systemFont(ofSize size: CGFloat, weight: PlatformFont.Weight = .regular) -> PlatformFont {
        #if canImport(AppKit)
        return NSFont.systemFont(ofSize: size, weight: weight)
        #else
        return UIFont.systemFont(ofSize: size, weight: weight)
        #endif
    }

    /// Returns the standard system font size for the current platform
    public static var systemFontSize: CGFloat {
        #if canImport(AppKit)
        return NSFont.systemFontSize
        #else
        return UIFont.systemFontSize
        #endif
    }
}
