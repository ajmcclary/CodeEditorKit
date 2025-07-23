import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
/// Cross-platform color type (NSColor on macOS)
public typealias PlatformColor = NSColor
/// Cross-platform font type (NSFont on macOS)
public typealias PlatformFont = NSFont
/// Cross-platform view type (NSView on macOS)
public typealias PlatformView = NSView
/// Cross-platform scroll view type (NSScrollView on macOS)
public typealias PlatformScrollView = NSScrollView
/// Cross-platform text view type (NSTextView on macOS)
public typealias PlatformTextView = NSTextView
/// Cross-platform image type (NSImage on macOS)
public typealias PlatformImage = NSImage
/// Cross-platform image view type (NSImageView on macOS)
public typealias PlatformImageView = NSImageView
/// Cross-platform bezier path type (NSBezierPath on macOS)
public typealias PlatformBezierPath = NSBezierPath
/// Cross-platform event type (NSEvent on macOS)
public typealias PlatformEvent = NSEvent
/// Cross-platform gesture recognizer type (NSGestureRecognizer on macOS)
public typealias PlatformGestureRecognizer = NSGestureRecognizer
/// Cross-platform view controller type (NSViewController on macOS)
public typealias PlatformViewController = NSViewController
/// Cross-platform context menu type (NSMenu on macOS)
public typealias PlatformContextMenu = NSMenu
/// Cross-platform autoresizing mask type (NSView.AutoresizingMask on macOS)
public typealias PlatformAutoresizingMask = NSView.AutoresizingMask
#else
import UIKit
/// Cross-platform color type (UIColor on iOS)
public typealias PlatformColor = UIColor
/// Cross-platform font type (UIFont on iOS)
public typealias PlatformFont = UIFont
/// Cross-platform view type (UIView on iOS)
public typealias PlatformView = UIView
/// Cross-platform scroll view type (UIScrollView on iOS)
public typealias PlatformScrollView = UIScrollView
/// Cross-platform text view type (UITextView on iOS)
public typealias PlatformTextView = UITextView
/// Cross-platform image type (UIImage on iOS)
public typealias PlatformImage = UIImage
/// Cross-platform image view type (UIImageView on iOS)
public typealias PlatformImageView = UIImageView
/// Cross-platform bezier path type (UIBezierPath on iOS)
public typealias PlatformBezierPath = UIBezierPath
/// Cross-platform event type (UIEvent on iOS)
public typealias PlatformEvent = UIEvent
/// Cross-platform gesture recognizer type (UIGestureRecognizer on iOS)
public typealias PlatformGestureRecognizer = UIGestureRecognizer
/// Cross-platform view controller type (UIViewController on iOS)
public typealias PlatformViewController = UIViewController
/// Cross-platform context menu type (UIMenu on iOS)
public typealias PlatformContextMenu = UIMenu
/// Cross-platform autoresizing mask type (UIView.AutoresizingMask on iOS)
public typealias PlatformAutoresizingMask = UIView.AutoresizingMask
#endif

// Cross-platform color aliases are now defined in PlatformColors.swift
// Cross-platform font helpers are now defined in PlatformFonts.swift
// This keeps PlatformImports focused on type definitions

/// Cross-platform autoresizing mask helpers
/// 
/// Provides consistent autoresizing behavior across macOS and iOS
/// by abstracting platform-specific autoresizing mask differences.
public enum PlatformAutoresizing {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// Flexible width resizing (NSView.AutoresizingMask.width on macOS)
    public static let flexibleWidth = NSView.AutoresizingMask.width
    /// Flexible height resizing (NSView.AutoresizingMask.height on macOS)
    public static let flexibleHeight = NSView.AutoresizingMask.height
    /// Flexible left margin (NSView.AutoresizingMask.minXMargin on macOS)
    public static let flexibleLeftMargin = NSView.AutoresizingMask.minXMargin
    /// Flexible right margin (NSView.AutoresizingMask.maxXMargin on macOS)
    public static let flexibleRightMargin = NSView.AutoresizingMask.maxXMargin
    /// Flexible top margin (NSView.AutoresizingMask.maxYMargin on macOS)
    public static let flexibleTopMargin = NSView.AutoresizingMask.maxYMargin
    /// Flexible bottom margin (NSView.AutoresizingMask.minYMargin on macOS)
    public static let flexibleBottomMargin = NSView.AutoresizingMask.minYMargin
    /// Combined flexible width and height
    public static let flexibleWidthAndHeight: PlatformAutoresizingMask = [.width, .height]
    /// No automatic resizing
    public static let noResizing = NSView.AutoresizingMask()
    #else
    /// Flexible width resizing (UIView.AutoresizingMask.flexibleWidth on iOS)
    public static let flexibleWidth = UIView.AutoresizingMask.flexibleWidth
    /// Flexible height resizing (UIView.AutoresizingMask.flexibleHeight on iOS)
    public static let flexibleHeight = UIView.AutoresizingMask.flexibleHeight
    /// Flexible left margin (UIView.AutoresizingMask.flexibleLeftMargin on iOS)
    public static let flexibleLeftMargin = UIView.AutoresizingMask.flexibleLeftMargin
    /// Flexible right margin (UIView.AutoresizingMask.flexibleRightMargin on iOS)
    public static let flexibleRightMargin = UIView.AutoresizingMask.flexibleRightMargin
    /// Flexible top margin (UIView.AutoresizingMask.flexibleTopMargin on iOS)
    public static let flexibleTopMargin = UIView.AutoresizingMask.flexibleTopMargin
    /// Flexible bottom margin (UIView.AutoresizingMask.flexibleBottomMargin on iOS)
    public static let flexibleBottomMargin = UIView.AutoresizingMask.flexibleBottomMargin
    /// Combined flexible width and height
    public static let flexibleWidthAndHeight: PlatformAutoresizingMask = [.flexibleWidth, .flexibleHeight]
    /// No automatic resizing
    public static let noResizing = UIView.AutoresizingMask()
    #endif
}
