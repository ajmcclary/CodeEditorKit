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
#endif

// Common color extensions
extension PlatformColor {
    #if canImport(AppKit)
    public static var label: PlatformColor { .labelColor }
    public static var secondaryLabel: PlatformColor { .secondaryLabelColor }
    public static var tertiaryLabel: PlatformColor { .tertiaryLabelColor }
    public static var systemBackground: PlatformColor { .windowBackgroundColor }
    public static var secondarySystemBackground: PlatformColor { .controlBackgroundColor }
    #endif
}
