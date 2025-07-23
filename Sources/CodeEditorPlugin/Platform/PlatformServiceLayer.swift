import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - Platform Service Layer

/// Centralized platform service layer that abstracts platform-specific operations
/// Eliminates scattered platform detection logic and provides unified interfaces
@MainActor
public final class PlatformServiceLayer {
    // MARK: - Singleton

    public static let shared = PlatformServiceLayer()

    private init() {}

    // MARK: - Device Detection Service

    /// Centralized device and platform detection
    public var deviceService: PlatformDeviceService {
        PlatformDeviceService.shared
    }

    /// Platform-specific menu service
    public var menuService: PlatformMenuService {
        #if canImport(UIKit)
        return UIKitMenuService()
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        return AppKitMenuService()
        #else
        return MockMenuService()
        #endif
    }

    /// Platform-specific input handling service
    public var inputService: PlatformInputService {
        #if canImport(UIKit)
        return UIKitInputService()
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        return AppKitInputService()
        #else
        return MockInputService()
        #endif
    }

    /// Platform-specific layout service
    public var layoutService: PlatformLayoutService {
        #if canImport(UIKit)
        return UIKitLayoutService()
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
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
    public static let shared = PlatformDeviceService()

    private init() {}

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

    /// Whether the app is running on Mac Catalyst
    public var isMacCatalyst: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        return false
        #endif
    }

    /// Whether the current platform is macOS (native)
    public var isMacOS: Bool {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return true
        #else
        return false
        #endif
    }

    /// Whether the current platform is iOS (including iPhone and iPad)
    public var isIOS: Bool {
        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
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
            return UIDevice.current.userInterfaceIdiom == .pad || isMacCatalyst
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
        return isIPad || isMacCatalyst
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
            return isIPad || isMacCatalyst
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
        return isIPad || isMacCatalyst
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
        return UIScreen.main.scale
        #elseif canImport(AppKit)
        return NSScreen.main?.backingScaleFactor ?? 1.0
        #else
        return 1.0
        #endif
    }

    /// Main screen bounds
    public var screenBounds: CGRect {
        #if canImport(UIKit)
        return UIScreen.main.bounds
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

@MainActor
public protocol PlatformMenuService {
    func createContextMenu(from descriptor: MenuDescriptor) -> PlatformServiceMenu?
    func showContextMenu(_ menu: PlatformServiceMenu, at point: CGPoint, in view: PlatformServiceView)
}

// MARK: - Platform Input Service Protocol

@MainActor
public protocol PlatformInputService {
    func handleKeyInput(key: String, modifiers: ModifierFlags, in view: PlatformServiceView) -> Bool
    func registerPlatformKeyboardShortcut(_ shortcut: PlatformKeyboardShortcut, action: @escaping () -> Void)
    func unregisterPlatformKeyboardShortcut(_ shortcut: PlatformKeyboardShortcut)
}

// MARK: - Platform Layout Service Protocol

@MainActor
public protocol PlatformLayoutService {
    func calculatePreferredSize(for view: PlatformServiceView, fitting size: CGSize) -> CGSize
    func layoutSubviews(in container: PlatformServiceView)
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
public typealias PlatformServiceView = UIView
public typealias PlatformServiceMenu = UIMenu
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
public typealias PlatformServiceView = NSView
public typealias PlatformServiceMenu = NSMenu
#else
public typealias PlatformServiceView = Any
public typealias PlatformServiceMenu = Any
#endif
