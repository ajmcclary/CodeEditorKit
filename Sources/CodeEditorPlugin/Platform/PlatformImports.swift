import Foundation
#if canImport(AppKit)
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
    #if canImport(AppKit)
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
    public static var textBackgroundColor: PlatformColor { NSColor.textBackgroundColor }
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
    public static var textBackgroundColor: PlatformColor { UIColor.systemBackground }
    #endif
}

// Cross-platform font helpers
public enum PlatformFonts {
    public static func monospacedSystemFont(ofSize size: CGFloat, weight: PlatformFont.Weight = .regular) -> PlatformFont {
        #if canImport(AppKit)
        return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        #else
        return UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        #endif
    }
    
    public static func systemFont(ofSize size: CGFloat, weight: PlatformFont.Weight = .regular) -> PlatformFont {
        #if canImport(AppKit)
        return NSFont.systemFont(ofSize: size, weight: weight)
        #else
        return UIFont.systemFont(ofSize: size, weight: weight)
        #endif
    }
    
    public static var systemFontSize: CGFloat {
        #if canImport(AppKit)
        return NSFont.systemFontSize
        #else
        return UIFont.systemFontSize
        #endif
    }
}
