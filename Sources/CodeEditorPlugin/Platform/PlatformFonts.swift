import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#else
import UIKit
#endif

// MARK: - Cross-Platform Font Helpers

public enum PlatformFonts {
    /// Creates a monospaced system font with the specified size and weight
    public static func monospacedSystemFont(ofSize size: CGFloat, weight: PlatformFont.Weight = .regular) -> PlatformFont {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        #else
        return UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        #endif
    }
    
    /// Creates a system font with the specified size and weight
    public static func systemFont(ofSize size: CGFloat, weight: PlatformFont.Weight = .regular) -> PlatformFont {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return NSFont.systemFont(ofSize: size, weight: weight)
        #else
        return UIFont.systemFont(ofSize: size, weight: weight)
        #endif
    }
    
    /// Returns the standard system font size for the current platform
    public static var systemFontSize: CGFloat {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return NSFont.systemFontSize
        #else
        return UIFont.systemFontSize
        #endif
    }
}
