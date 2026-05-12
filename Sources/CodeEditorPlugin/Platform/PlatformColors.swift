import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Unified cross-platform color system providing consistent API across iOS and macOS
///
/// `PlatformColors` centralizes all platform color definitions and provides semantic
/// color mappings that adapt automatically to light/dark mode and platform conventions.
///
/// ## Overview
///
/// This enum serves as the single source of truth for all platform colors used throughout
/// the code editor. It abstracts platform differences between UIColor and NSColor while
/// providing semantic color names that work consistently across all platforms.
///
/// ## Usage
///
/// ```swift
/// // Basic platform colors
/// let background = PlatformColors.systemBackground
/// let text = PlatformColors.label
/// 
/// // Semantic editor colors
/// let lineHighlight = PlatformColors.selectedLineHighlight
/// let gutter = PlatformColors.gutterBackground
/// let lineNumbers = PlatformColors.lineNumberColor
/// ```
///
/// ## Platform Adaptation
///
/// Colors automatically adapt to:
/// - Light and dark appearance modes
/// - Platform-specific design conventions
/// - Accessibility settings and contrast preferences
/// - System accent color changes
///
/// See `docs/Platform/platform-abstraction.md` for platform adaptation details.
public enum PlatformColors {
    // MARK: - Basic Platform Colors

    /// Primary label color (adapts to light/dark mode)
    public static var label: PlatformColor {
        #if canImport(AppKit)
        return NSColor.labelColor
        #else
        return UIColor.label
        #endif
    }

    /// Secondary label color (dimmed)
    public static var secondaryLabel: PlatformColor {
        #if canImport(AppKit)
        return NSColor.secondaryLabelColor
        #else
        return UIColor.secondaryLabel
        #endif
    }

    /// Tertiary label color (further dimmed)
    public static var tertiaryLabel: PlatformColor {
        #if canImport(AppKit)
        return NSColor.tertiaryLabelColor
        #else
        return UIColor.tertiaryLabel
        #endif
    }

    /// Primary system background color
    public static var systemBackground: PlatformColor {
        #if canImport(AppKit)
        return NSColor.windowBackgroundColor
        #else
        return UIColor.systemBackground
        #endif
    }

    /// Secondary system background color
    public static var secondarySystemBackground: PlatformColor {
        #if canImport(AppKit)
        return NSColor.controlBackgroundColor
        #else
        return UIColor.secondarySystemBackground
        #endif
    }

    /// Control background color
    public static var controlBackground: PlatformColor {
        #if canImport(AppKit)
        return NSColor.controlBackgroundColor
        #else
        return UIColor.systemGray6
        #endif
    }

    /// Separator line color
    public static var separator: PlatformColor {
        #if canImport(AppKit)
        return NSColor.separatorColor
        #else
        return UIColor.separator
        #endif
    }

    /// Disabled control text color
    public static var disabledControlText: PlatformColor {
        #if canImport(AppKit)
        return NSColor.disabledControlTextColor
        #else
        return UIColor.tertiaryLabel
        #endif
    }

    /// System accent/tint color
    public static var tintColor: PlatformColor {
        #if canImport(AppKit)
        return NSColor.controlAccentColor
        #else
        return UIColor.tintColor
        #endif
    }

    /// Control accent color (same as tint on iOS, dedicated property on macOS)
    public static var controlAccentColor: PlatformColor {
        #if canImport(AppKit)
        return NSColor.controlAccentColor
        #else
        return UIColor.systemBlue
        #endif
    }

    /// Text background color (for text fields, editors)
    public static var textBackgroundColor: PlatformColor {
        #if canImport(AppKit)
        return NSColor.textBackgroundColor
        #else
        return UIColor.systemBackground
        #endif
    }

    /// Placeholder text color
    public static var placeholderTextColor: PlatformColor {
        #if canImport(AppKit)
        return NSColor.placeholderTextColor
        #else
        return UIColor.placeholderText
        #endif
    }

    /// Selected text color
    public static var selectedTextColor: PlatformColor {
        #if canImport(AppKit)
        return NSColor.selectedTextColor
        #else
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? .white : .black
        }
        #endif
    }

    /// Selected text background color
    public static var selectedTextBackgroundColor: PlatformColor {
        #if canImport(AppKit)
        return NSColor.selectedTextBackgroundColor
        #else
        return UIColor.tintColor.withAlphaComponent(0.3)
        #endif
    }

    // MARK: - Basic Colors

    /// Pure black color
    public static var black: PlatformColor {
        #if canImport(AppKit)
        return NSColor.black
        #else
        return UIColor.black
        #endif
    }

    /// Pure white color
    public static var white: PlatformColor {
        #if canImport(AppKit)
        return NSColor.white
        #else
        return UIColor.white
        #endif
    }

    /// Fully transparent color
    public static var clear: PlatformColor {
        #if canImport(AppKit)
        return NSColor.clear
        #else
        return UIColor.clear
        #endif
    }

    // MARK: - System Colors

    /// System red color that adapts to appearance changes
    public static var systemRed: PlatformColor {
        #if canImport(AppKit)
        return NSColor.systemRed
        #else
        return UIColor.systemRed
        #endif
    }

    /// System blue color that adapts to appearance changes
    public static var systemBlue: PlatformColor {
        #if canImport(AppKit)
        return NSColor.systemBlue
        #else
        return UIColor.systemBlue
        #endif
    }

    /// System green color that adapts to appearance changes
    public static var systemGreen: PlatformColor {
        #if canImport(AppKit)
        return NSColor.systemGreen
        #else
        return UIColor.systemGreen
        #endif
    }

    /// System purple color that adapts to appearance changes
    public static var systemPurple: PlatformColor {
        #if canImport(AppKit)
        return NSColor.systemPurple
        #else
        return UIColor.systemPurple
        #endif
    }

    /// System orange color that adapts to appearance changes
    public static var systemOrange: PlatformColor {
        #if canImport(AppKit)
        return NSColor.systemOrange
        #else
        return UIColor.systemOrange
        #endif
    }

    /// System teal color that adapts to appearance changes
    public static var systemTeal: PlatformColor {
        #if canImport(AppKit)
        return NSColor.systemTeal
        #else
        return UIColor.systemTeal
        #endif
    }

    /// System indigo color that adapts to appearance changes
    public static var systemIndigo: PlatformColor {
        #if canImport(AppKit)
        return NSColor.systemIndigo
        #else
        return UIColor.systemIndigo
        #endif
    }

    /// System pink color that adapts to appearance changes
    public static var systemPink: PlatformColor {
        #if canImport(AppKit)
        return NSColor.systemPink
        #else
        return UIColor.systemPink
        #endif
    }

    /// System brown color that adapts to appearance changes
    public static var systemBrown: PlatformColor {
        #if canImport(AppKit)
        return NSColor.systemBrown
        #else
        return UIColor.systemBrown
        #endif
    }

    /// System yellow color that adapts to appearance changes
    public static var systemYellow: PlatformColor {
        #if canImport(AppKit)
        return NSColor.systemYellow
        #else
        return UIColor.systemYellow
        #endif
    }

    /// System gray color that adapts to appearance changes
    public static var systemGray: PlatformColor {
        #if canImport(AppKit)
        return NSColor.systemGray
        #else
        return UIColor.systemGray
        #endif
    }
}

// MARK: - Semantic Code Editor Colors

extension PlatformColors {
    /// Returns an appropriate highlight color for the selected line
    /// Adapts to light/dark mode automatically
    public static var selectedLineHighlight: PlatformColor {
        tintColor.withAlphaComponent(0.15)
    }

    /// Returns an appropriate color for code editor background
    public static var codeBackground: PlatformColor {
        #if canImport(UIKit)
        return systemBackground
        #else
        return textBackgroundColor
        #endif
    }

    /// Returns an appropriate color for gutter background
    public static var gutterBackground: PlatformColor {
        #if canImport(UIKit)
        return secondarySystemBackground
        #else
        return controlBackground
        #endif
    }

    /// Returns an appropriate color for line numbers
    public static var lineNumberColor: PlatformColor {
        tertiaryLabel
    }

    /// Returns an appropriate color for syntax highlighting keywords
    public static var keywordColor: PlatformColor {
        systemPurple
    }

    /// Returns an appropriate color for syntax highlighting strings
    public static var stringColor: PlatformColor {
        systemRed
    }

    /// Returns an appropriate color for syntax highlighting comments
    public static var commentColor: PlatformColor {
        systemGreen
    }

    /// Returns an appropriate color for syntax highlighting numbers
    public static var numberColor: PlatformColor {
        systemBlue
    }

    /// Returns an appropriate color for syntax highlighting functions
    public static var functionColor: PlatformColor {
        systemTeal
    }

    /// Returns an appropriate color for syntax highlighting types
    public static var typeColor: PlatformColor {
        systemIndigo
    }

    /// Returns an appropriate color for syntax highlighting attributes
    public static var attributeColor: PlatformColor {
        systemOrange
    }
}

// Platform-specific helpers are defined in PlatformColor+Extensions.swift
