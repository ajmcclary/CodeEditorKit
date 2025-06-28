import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
public typealias PlatformColor = NSColor
public typealias PlatformFont = NSFont
public typealias PlatformView = NSView
public typealias PlatformScrollView = NSScrollView
public typealias PlatformTextView = NSTextView
public typealias PlatformImage = NSImage
public typealias PlatformBezierPath = NSBezierPath
public typealias PlatformEvent = NSEvent
public typealias PlatformTouch = NSTouch
public typealias PlatformGestureRecognizer = NSGestureRecognizer
public typealias PlatformPasteboard = NSPasteboard
public typealias PlatformViewController = NSViewController
public typealias PlatformContextMenu = NSMenu
#else
import UIKit
public typealias PlatformColor = UIColor
public typealias PlatformFont = UIFont
public typealias PlatformView = UIView
public typealias PlatformScrollView = UIScrollView
public typealias PlatformTextView = UITextView
public typealias PlatformImage = UIImage
public typealias PlatformBezierPath = UIBezierPath
public typealias PlatformEvent = UIEvent
public typealias PlatformTouch = UITouch
public typealias PlatformGestureRecognizer = UIGestureRecognizer
public typealias PlatformPasteboard = UIPasteboard
public typealias PlatformViewController = UIViewController
public typealias PlatformContextMenu = UIMenu
#endif

// Cross-platform color aliases
public enum PlatformColors {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public static var label: PlatformColor { NSColor.labelColor }
    public static var secondaryLabel: PlatformColor { NSColor.secondaryLabelColor }
    public static var tertiaryLabel: PlatformColor { NSColor.tertiaryLabelColor }
    public static var systemBackground: PlatformColor { NSColor.windowBackgroundColor }
    public static var secondarySystemBackground: PlatformColor { NSColor.controlBackgroundColor }
    public static var controlBackground: PlatformColor { NSColor.controlBackgroundColor }
    public static var separator: PlatformColor { NSColor.separatorColor }
    public static var disabledControlText: PlatformColor { NSColor.disabledControlTextColor }
    public static var black: PlatformColor { NSColor.black }
    public static var clear: PlatformColor { NSColor.clear }
    public static var controlAccentColor: PlatformColor { NSColor.controlAccentColor }
    public static var tintColor: PlatformColor { NSColor.controlAccentColor } // macOS doesn't have tintColor, using controlAccentColor
    public static var textBackgroundColor: PlatformColor { NSColor.textBackgroundColor }
    public static var placeholderTextColor: PlatformColor { NSColor.placeholderTextColor }
    public static var selectedTextColor: PlatformColor { NSColor.selectedTextColor }
    public static var selectedTextBackgroundColor: PlatformColor { NSColor.selectedTextBackgroundColor }
    
    // System colors
    public static var systemRed: PlatformColor { NSColor.systemRed }
    public static var systemBlue: PlatformColor { NSColor.systemBlue }
    public static var systemGreen: PlatformColor { NSColor.systemGreen }
    public static var systemPurple: PlatformColor { NSColor.systemPurple }
    public static var systemOrange: PlatformColor { NSColor.systemOrange }
    public static var systemTeal: PlatformColor { NSColor.systemTeal }
    public static var systemIndigo: PlatformColor { NSColor.systemIndigo }
    public static var systemPink: PlatformColor { NSColor.systemPink }
    public static var systemBrown: PlatformColor { NSColor.systemBrown }
    #else
    public static var label: PlatformColor { UIColor.label }
    public static var secondaryLabel: PlatformColor { UIColor.secondaryLabel }
    public static var tertiaryLabel: PlatformColor { UIColor.tertiaryLabel }
    public static var systemBackground: PlatformColor { UIColor.systemBackground }
    public static var secondarySystemBackground: PlatformColor { UIColor.secondarySystemBackground }
    public static var controlBackground: PlatformColor { UIColor.systemGray6 }
    public static var separator: PlatformColor { UIColor.separator }
    public static var disabledControlText: PlatformColor { UIColor.tertiaryLabel }
    public static var black: PlatformColor { UIColor.black }
    public static var clear: PlatformColor { UIColor.clear }
    public static var controlAccentColor: PlatformColor { UIColor.systemBlue }
    public static var tintColor: PlatformColor { UIColor.tintColor }
    public static var textBackgroundColor: PlatformColor { UIColor.systemBackground }
    public static var placeholderTextColor: PlatformColor { UIColor.placeholderText }
    public static var selectedTextColor: PlatformColor { UIColor.label } // iOS doesn't have selectedTextColor, using label
    public static var selectedTextBackgroundColor: PlatformColor { UIColor.systemBlue.withAlphaComponent(0.3) } // iOS doesn't have selectedTextBackgroundColor
    
    // System colors
    public static var systemRed: PlatformColor { UIColor.systemRed }
    public static var systemBlue: PlatformColor { UIColor.systemBlue }
    public static var systemGreen: PlatformColor { UIColor.systemGreen }
    public static var systemPurple: PlatformColor { UIColor.systemPurple }
    public static var systemOrange: PlatformColor { UIColor.systemOrange }
    public static var systemTeal: PlatformColor { UIColor.systemTeal }
    public static var systemIndigo: PlatformColor { UIColor.systemIndigo }
    public static var systemPink: PlatformColor { UIColor.systemPink }
    public static var systemBrown: PlatformColor { UIColor.systemBrown }
    #endif
}

// Cross-platform font helpers
public enum PlatformFonts {
    public static func monospacedSystemFont(ofSize size: CGFloat, weight: PlatformFont.Weight = .regular) -> PlatformFont {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        #else
        return UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        #endif
    }
    
    public static func systemFont(ofSize size: CGFloat, weight: PlatformFont.Weight = .regular) -> PlatformFont {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return NSFont.systemFont(ofSize: size, weight: weight)
        #else
        return UIFont.systemFont(ofSize: size, weight: weight)
        #endif
    }
    
    public static var systemFontSize: CGFloat {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return NSFont.systemFontSize
        #else
        return UIFont.systemFontSize
        #endif
    }
}
