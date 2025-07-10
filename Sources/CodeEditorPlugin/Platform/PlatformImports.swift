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
public typealias PlatformAutoresizingMask = NSView.AutoresizingMask
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
public typealias PlatformAutoresizingMask = UIView.AutoresizingMask
#endif

// Cross-platform color aliases are now defined in PlatformColors.swift
// Cross-platform font helpers are now defined in PlatformFonts.swift
// This keeps PlatformImports focused on type definitions

// Cross-platform autoresizing mask helpers
public enum PlatformAutoresizing {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public static let flexibleWidth = NSView.AutoresizingMask.width
    public static let flexibleHeight = NSView.AutoresizingMask.height
    public static let flexibleLeftMargin = NSView.AutoresizingMask.minXMargin
    public static let flexibleRightMargin = NSView.AutoresizingMask.maxXMargin
    public static let flexibleTopMargin = NSView.AutoresizingMask.maxYMargin
    public static let flexibleBottomMargin = NSView.AutoresizingMask.minYMargin
    public static let flexibleWidthAndHeight: PlatformAutoresizingMask = [.width, .height]
    public static let noResizing = NSView.AutoresizingMask()
    #else
    public static let flexibleWidth = UIView.AutoresizingMask.flexibleWidth
    public static let flexibleHeight = UIView.AutoresizingMask.flexibleHeight
    public static let flexibleLeftMargin = UIView.AutoresizingMask.flexibleLeftMargin
    public static let flexibleRightMargin = UIView.AutoresizingMask.flexibleRightMargin
    public static let flexibleTopMargin = UIView.AutoresizingMask.flexibleTopMargin
    public static let flexibleBottomMargin = UIView.AutoresizingMask.flexibleBottomMargin
    public static let flexibleWidthAndHeight: PlatformAutoresizingMask = [.flexibleWidth, .flexibleHeight]
    public static let noResizing = UIView.AutoresizingMask()
    #endif
}
