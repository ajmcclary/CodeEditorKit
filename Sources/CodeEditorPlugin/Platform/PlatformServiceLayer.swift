import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Platform Service Layer

/// Centralized platform service layer that abstracts platform-specific operations
/// Eliminates scattered platform detection logic and provides unified interfaces
@MainActor
public final class PlatformServiceLayer {
    // MARK: - Owned Services

    private let _deviceService = PlatformDeviceService()

    /// Public initializer for dependency injection
    public init() {}

    // MARK: - Device Detection Service

    /// Centralized device and platform detection
    public var deviceService: PlatformDeviceService {
        _deviceService
    }

    /// Platform-specific menu service
    public var menuService: PlatformMenuService {
        #if canImport(UIKit)
        return UIKitMenuService()
        #elseif canImport(AppKit)
        return AppKitMenuService()
        #else
        return MockMenuService()
        #endif
    }

    /// Platform-specific input handling service
    public var inputService: PlatformInputService {
        #if canImport(UIKit)
        return UIKitInputService()
        #elseif canImport(AppKit)
        return AppKitInputService()
        #else
        return MockInputService()
        #endif
    }

    /// Platform-specific layout service
    public var layoutService: PlatformLayoutService {
        #if canImport(UIKit)
        return UIKitLayoutService()
        #elseif canImport(AppKit)
        return AppKitLayoutService()
        #else
        return MockLayoutService()
        #endif
    }
}

// MARK: - Platform Device Service

/// Centralized device detection service that replaces scattered UIDevice.current checks
@MainActor
public final class PlatformDeviceService {
    /// Public initializer for dependency injection
    public init() {}

    // MARK: - Device Type Detection

    /// Whether the current device is an iPad
    public var isIPad: Bool {
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }

    /// Whether the current device is an iPhone
    public var isIPhone: Bool {
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .phone
        #else
        return false
        #endif
    }

    /// Whether the current platform is macOS (native)
    public var isMacOS: Bool {
        #if canImport(AppKit)
        return true
        #else
        return false
        #endif
    }

    /// Whether the current platform is iOS (including iPhone and iPad)
    public var isIOS: Bool {
        #if canImport(UIKit)
        return true
        #else
        return false
        #endif
    }

    // MARK: - Capability Detection

    /// Whether the device supports hover interactions
    public var supportsHover: Bool {
        #if canImport(UIKit)
        if #available(iOS 13.4, *) {
            return UIDevice.current.userInterfaceIdiom == .pad
        }
        return false
        #elseif canImport(AppKit)
        return true
        #else
        return false
        #endif
    }

    /// Whether the device supports keyboard shortcuts
    public var supportsPlatformKeyboardShortcuts: Bool {
        #if canImport(UIKit)
        return isIPad
        #elseif canImport(AppKit)
        return true
        #else
        return false
        #endif
    }

    /// Whether the device supports multiple windows
    public var supportsMultipleWindows: Bool {
        #if canImport(UIKit)
        if #available(iOS 13.0, *) {
            return isIPad
        }
        return false
        #elseif canImport(AppKit)
        return true
        #else
        return false
        #endif
    }

    /// Whether the device supports external displays
    public var supportsExternalDisplay: Bool {
        #if canImport(UIKit)
        return isIPad
        #elseif canImport(AppKit)
        return true
        #else
        return false
        #endif
    }

    // MARK: - Screen Properties

    /// Main screen scale factor
    public var screenScale: CGFloat {
        #if canImport(UIKit)
        return UIKitScreenMetrics.scale
        #elseif canImport(AppKit)
        return NSScreen.main?.backingScaleFactor ?? 1.0
        #else
        return 1.0
        #endif
    }

    /// Main screen bounds
    public var screenBounds: CGRect {
        #if canImport(UIKit)
        return UIKitScreenMetrics.bounds
        #elseif canImport(AppKit)
        return NSScreen.main?.frame ?? .zero
        #else
        return .zero
        #endif
    }

    // MARK: - Device-Specific Preferences

    /// Preferred text size for the platform
    public var preferredTextSize: CGFloat {
        if isIPhone {
            return 16.0
        } else if isIPad {
            return 17.0
        } else {
            return 13.0 // macOS default
        }
    }

    /// Whether to use compact UI elements
    public var prefersCompactUI: Bool {
        isIPhone
    }

    /// Recommended touch target size
    public var recommendedTouchTargetSize: CGFloat {
        if isIOS {
            return 44.0 // iOS HIG
        } else {
            return 32.0 // macOS typical
        }
    }
}

// MARK: - Platform Menu Service Protocol

/// Service protocol for platform-specific menu operations
/// 
/// This protocol defines the interface for creating and displaying context menus
/// across different platforms (macOS, iOS, iPadOS).
@MainActor
public protocol PlatformMenuService {
    /// Creates a context menu from a menu descriptor
    /// - Parameter descriptor: The menu configuration
    /// - Returns: Platform-specific menu instance, or nil if creation fails
    func createContextMenu(from descriptor: MenuDescriptor) -> PlatformServiceMenu?

    /// Shows a context menu at a specific location
    /// - Parameters:
    ///   - menu: The menu to display
    ///   - point: Screen coordinate for menu placement
    ///   - view: The view that will host the menu
    func showContextMenu(_ menu: PlatformServiceMenu, at point: CGPoint, in view: PlatformServiceView)
}

// MARK: - Platform Input Service Protocol

/// Platform-specific input handling service protocol
/// Provides abstractions for handling user input across different Apple platforms
@MainActor
public protocol PlatformInputService {
    /// Handles key input events
    /// - Parameters:
    ///   - key: The key that was pressed
    ///   - modifiers: Modifier keys held during press
    ///   - view: The view that received the input
    /// - Returns: `true` if the input was handled, `false` otherwise
    func handleKeyInput(key: String, modifiers: ModifierFlags, in view: PlatformServiceView) -> Bool

    /// Registers a keyboard shortcut with an action
    /// - Parameters:
    ///   - shortcut: The keyboard shortcut to register
    ///   - action: The action to perform when shortcut is triggered
    func registerPlatformKeyboardShortcut(_ shortcut: PlatformKeyboardShortcut, action: @escaping () -> Void)

    /// Unregisters a previously registered keyboard shortcut
    /// - Parameter shortcut: The shortcut to unregister
    func unregisterPlatformKeyboardShortcut(_ shortcut: PlatformKeyboardShortcut)
}

// MARK: - Platform Layout Service Protocol

/// Platform-specific layout service protocol
/// Provides abstractions for view layout calculations across different Apple platforms
@MainActor
public protocol PlatformLayoutService {
    /// Calculates the preferred size for a view given constraints
    /// - Parameters:
    ///   - view: The view to measure
    ///   - size: The fitting size constraints
    /// - Returns: The preferred size for the view
    func calculatePreferredSize(for view: PlatformServiceView, fitting size: CGSize) -> CGSize

    /// Performs layout of subviews within a container
    /// - Parameter container: The container view to layout
    func layoutSubviews(in container: PlatformServiceView)

    /// Animates layout changes with the specified duration
    /// - Parameters:
    ///   - duration: Animation duration in seconds
    ///   - animations: Animation block to execute
    ///   - completion: Optional completion handler
    func animateLayoutChanges(duration: TimeInterval, animations: @escaping () -> Void, completion: (@Sendable (Bool) -> Void)?)
}

// MARK: - Supporting Types

public struct MenuDescriptor: Sendable {
    let items: [MenuItem]

    public init(items: [MenuItem]) {
        self.items = items
    }
}

public struct MenuItem: Sendable {
    let title: String
    let action: @Sendable () -> Void
    let shortcut: PlatformKeyboardShortcut?
    let isEnabled: Bool

    public init(title: String, action: @escaping @Sendable () -> Void, shortcut: PlatformKeyboardShortcut? = nil, isEnabled: Bool = true) {
        self.title = title
        self.action = action
        self.shortcut = shortcut
        self.isEnabled = isEnabled
    }
}

public struct PlatformKeyboardShortcut: Sendable {
    let key: String
    let modifiers: ModifierFlags

    public init(key: String, modifiers: ModifierFlags) {
        self.key = key
        self.modifiers = modifiers
    }
}

public struct ModifierFlags: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let command = Self(rawValue: 1 << 0)
    public static let option = Self(rawValue: 1 << 1)
    public static let control = Self(rawValue: 1 << 2)
    public static let shift = Self(rawValue: 1 << 3)
}

// MARK: - Platform Type Aliases

#if canImport(UIKit)
/// Platform-specific view type (UIView on iOS)
public typealias PlatformServiceView = UIView
/// Platform-specific menu type (UIMenu on iOS)
public typealias PlatformServiceMenu = UIMenu
#elseif canImport(AppKit)
/// Platform-specific view type (NSView on macOS)
public typealias PlatformServiceView = NSView
/// Platform-specific menu type (NSMenu on macOS)
public typealias PlatformServiceMenu = NSMenu
#else
/// Fallback view type for unsupported platforms
public typealias PlatformServiceView = Any
/// Fallback menu type for unsupported platforms
public typealias PlatformServiceMenu = Any
#endif
