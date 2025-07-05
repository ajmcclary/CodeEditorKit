import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
public typealias PlatformColor = NSColor
public typealias PlatformFont = NSFont
public typealias PlatformView = NSView
public typealias PlatformScrollView = NSScrollView
public typealias PlatformTextView = NSTextView
public typealias PlatformImage = NSImage
public typealias PlatformImageView = NSImageView
public typealias PlatformBezierPath = NSBezierPath
public typealias PlatformEvent = NSEvent
public typealias PlatformGestureRecognizer = NSGestureRecognizer
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
public typealias PlatformImageView = UIImageView
public typealias PlatformBezierPath = UIBezierPath
public typealias PlatformEvent = UIEvent
public typealias PlatformGestureRecognizer = UIGestureRecognizer
public typealias PlatformViewController = UIViewController
public typealias PlatformContextMenu = UIMenu
#endif

// Cross-platform color aliases are now defined in PlatformColors.swift
// This keeps PlatformImports focused on type definitions

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
