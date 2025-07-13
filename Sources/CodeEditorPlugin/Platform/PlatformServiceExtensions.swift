import Foundation

// MARK: - Platform Service Extensions

/// Extensions to simplify common platform service operations
extension PlatformServiceLayer {
    // MARK: - Quick Device Checks
    
    /// Quick access to device type without accessing deviceService directly
    public var isIPad: Bool { deviceService.isIPad }
    public var isIPhone: Bool { deviceService.isIPhone }
    public var isMacOS: Bool { deviceService.isMacOS }
    public var isMacCatalyst: Bool { deviceService.isMacCatalyst }
    
    /// Combined mobile check (iPhone or iPad, but not Mac Catalyst)
    public var isMobile: Bool { deviceService.isIOS }
    
    /// Desktop check (macOS or Mac Catalyst)
    public var isDesktop: Bool { deviceService.isMacOS || deviceService.isMacCatalyst }
    
    // MARK: - UI Configuration Helpers
    
    /// Determines if touch-optimized UI should be used
    public var shouldUseTouchOptimizedUI: Bool {
        deviceService.isIOS && !deviceService.isMacCatalyst
    }
    
    /// Determines if compact layout should be used
    public var shouldUseCompactLayout: Bool {
        deviceService.prefersCompactUI
    }
    
    /// Gets the appropriate line height for the current platform
    public func preferredLineHeight(for fontSize: CGFloat) -> CGFloat {
        if deviceService.isIOS {
            return fontSize * 1.2
        } else {
            return fontSize * 1.15
        }
    }
    
    /// Gets platform-appropriate spacing values
    public var standardSpacing: PlatformSpacing {
        if deviceService.isIPhone {
            return PlatformSpacing(small: 8, medium: 16, large: 24)
        } else if deviceService.isIPad {
            return PlatformSpacing(small: 12, medium: 20, large: 32)
        } else {
            return PlatformSpacing(small: 6, medium: 12, large: 20)
        }
    }
    
    // MARK: - Context Menu Helpers
    
    /// Creates a standard edit context menu
    public func createEditContextMenu(
        canCut: Bool = true,
        canCopy: Bool = true,
        canPaste: Bool = true,
        cutAction: @escaping @Sendable () -> Void = {},
        copyAction: @escaping @Sendable () -> Void = {},
        pasteAction: @escaping @Sendable () -> Void = {}
    ) -> PlatformServiceMenu? {
        var items: [MenuItem] = []
        
        if canCut {
            items.append(MenuItem(
                title: "Cut",
                action: cutAction,
                shortcut: PlatformKeyboardShortcut(key: "x", modifiers: .command)
            ))
        }
        
        if canCopy {
            items.append(MenuItem(
                title: "Copy",
                action: copyAction,
                shortcut: PlatformKeyboardShortcut(key: "c", modifiers: .command)
            ))
        }
        
        if canPaste {
            items.append(MenuItem(
                title: "Paste",
                action: pasteAction,
                shortcut: PlatformKeyboardShortcut(key: "v", modifiers: .command)
            ))
        }
        
        let descriptor = MenuDescriptor(items: items)
        return menuService.createContextMenu(from: descriptor)
    }
    
    // MARK: - Animation Helpers
    
    /// Platform-appropriate animation duration
    public var standardAnimationDuration: TimeInterval {
        if deviceService.isIOS {
            return 0.25
        } else {
            return 0.2
        }
    }
    
    /// Performs a layout animation with platform-appropriate settings
    public func animateLayoutChange(
        _ animations: @escaping () -> Void,
        completion: (@Sendable (Bool) -> Void)? = nil
    ) {
        layoutService.animateLayoutChanges(
            duration: standardAnimationDuration,
            animations: animations,
            completion: completion
        )
    }
}

// MARK: - Platform Spacing

public struct PlatformSpacing {
    public let small: CGFloat
    public let medium: CGFloat
    public let large: CGFloat
    
    public init(small: CGFloat, medium: CGFloat, large: CGFloat) {
        self.small = small
        self.medium = medium
        self.large = large
    }
}

// MARK: - Migration Helpers

/// Helper methods to ease migration from scattered platform detection
extension PlatformServiceLayer {
    /// Replaces scattered UIDevice.current.userInterfaceIdiom == .pad checks
    @available(*, deprecated, message: "Use PlatformServiceLayer.shared.isIPad instead")
    public static var isIPadDevice: Bool {
        shared.isIPad
    }
    
    /// Replaces scattered UIDevice.current.userInterfaceIdiom == .phone checks
    @available(*, deprecated, message: "Use PlatformServiceLayer.shared.isIPhone instead")
    public static var isIPhoneDevice: Bool {
        shared.isIPhone
    }
    
    /// Replaces scattered #if targetEnvironment(macCatalyst) checks
    @available(*, deprecated, message: "Use PlatformServiceLayer.shared.isMacCatalyst instead")
    public static var isMacCatalystEnvironment: Bool {
        shared.isMacCatalyst
    }
}

// MARK: - Platform Capability Extensions

extension PlatformDeviceService {
    /// Determines optimal text editor configuration for the current platform
    public var preferredEditorConfiguration: EditorConfigurationHints {
        EditorConfigurationHints(
            showLineNumbers: !isIPhone, // Hide on iPhone for space
            showMinimap: isMacOS || (isIPad && !isMacCatalyst), // Desktop and large screens
            enableWordWrap: isIPhone || prefersCompactUI, // Mobile-friendly
            fontSize: preferredTextSize,
            tabWidth: isIOS ? 2 : 4, // Smaller tabs on mobile
            showInvisibleCharacters: !isIOS // Desktop feature
        )
    }
    
    /// Determines if advanced features should be enabled
    public var shouldEnableAdvancedFeatures: Bool {
        isMacOS || isIPad
    }
    
    /// Determines maximum recommended file size for the platform
    public var maxRecommendedFileSize: Int {
        if isIPhone {
            return 100_000 // 100KB
        } else if isIPad {
            return 500_000 // 500KB
        } else {
            return 2_000_000 // 2MB
        }
    }
}

// MARK: - Editor Configuration Hints

public struct EditorConfigurationHints {
    public let showLineNumbers: Bool
    public let showMinimap: Bool
    public let enableWordWrap: Bool
    public let fontSize: CGFloat
    public let tabWidth: Int
    public let showInvisibleCharacters: Bool
    
    public init(
        showLineNumbers: Bool,
        showMinimap: Bool,
        enableWordWrap: Bool,
        fontSize: CGFloat,
        tabWidth: Int,
        showInvisibleCharacters: Bool
    ) {
        self.showLineNumbers = showLineNumbers
        self.showMinimap = showMinimap
        self.enableWordWrap = enableWordWrap
        self.fontSize = fontSize
        self.tabWidth = tabWidth
        self.showInvisibleCharacters = showInvisibleCharacters
    }
}
