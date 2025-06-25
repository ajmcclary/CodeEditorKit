#if canImport(AppKit)
import AppKit
public typealias PlatformColor = NSColor
public typealias PlatformFont = NSFont
public typealias PlatformView = NSView
public typealias PlatformViewController = NSViewController
#elseif canImport(UIKit)
import UIKit
public typealias PlatformColor = UIColor
public typealias PlatformFont = UIFont
public typealias PlatformView = UIView
public typealias PlatformViewController = UIViewController
#endif

// Color extensions for cross-platform compatibility
extension PlatformColor {
    #if canImport(UIKit)
    static var controlBackgroundColor: UIColor { .systemGray6 }
    static var windowBackgroundColor: UIColor { .systemBackground }
    static var labelColor: UIColor { .label }
    static var secondaryLabelColor: UIColor { .secondaryLabel }
    static var tertiaryLabelColor: UIColor { .tertiaryLabel }
    static var selectedTextBackgroundColor: UIColor { .systemBlue.withAlphaComponent(0.3) }
    static var selectedTextColor: UIColor { .white }
    static var controlAccentColor: UIColor { .tintColor }
    #endif
}
