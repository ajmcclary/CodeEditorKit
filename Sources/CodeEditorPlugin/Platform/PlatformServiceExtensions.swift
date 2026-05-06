import Foundation

// MARK: - Platform Service Extensions

/// Extensions to simplify common platform service operations
extension PlatformServiceLayer {
    // MARK: - Quick Device Checks

    /// Quick access to device type without accessing deviceService directly
    /// Returns `true` if the current device is an iPad
    public var isIPad: Bool { deviceService.isIPad }

    /// Returns `true` if the current device is an iPhone
    public var isIPhone: Bool { deviceService.isIPhone }

    /// Returns `true` if the current platform is macOS
    public var isMacOS: Bool { deviceService.isMacOS }

    /// Returns `true` if the current platform is Mac Catalyst
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

/// Platform-appropriate spacing values for different UI elements
///
/// Provides standardized spacing values that adapt to platform conventions
/// and device characteristics for consistent UI appearance.
public struct PlatformSpacing {
    /// Small spacing value (typically 6-12pt)
    public let small: CGFloat

    /// Medium spacing value (typically 12-20pt)
    public let medium: CGFloat

    /// Large spacing value (typically 20-32pt)
    public let large: CGFloat

    /// Creates platform spacing with custom values
    /// - Parameters:
    ///   - small: Small spacing value
    ///   - medium: Medium spacing value
    ///   - large: Large spacing value
    public init(small: CGFloat, medium: CGFloat, large: CGFloat) {
        self.small = small
        self.medium = medium
        self.large = large
    }
}

// MARK: - Migration Helpers

// MARK: - Platform Capability Extensions

extension PlatformDeviceService {
    /// Determines optimal text editor configuration for the current platform
    public var preferredEditorConfiguration: EditorConfigurationHints {
        EditorConfigurationHints(
            showLineNumbers: !isIPhone, // Hide on iPhone for space
            isMinimapVisible: isMacOS || (isIPad && !isMacCatalyst), // Desktop and large screens
            enableWordWrap: isIPhone || prefersCompactUI, // Mobile-friendly
            fontSize: preferredTextSize,
            tabWidth: isIOS ? 2 : 4, // Smaller tabs on mobile
            areInvisibleCharactersVisible: !isIOS // Desktop feature
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

/// Platform-optimized editor configuration recommendations
///
/// Provides sensible defaults for editor configuration based on
/// platform capabilities and user interface conventions.
public struct EditorConfigurationHints {
    /// Whether line numbers should be displayed
    public let showLineNumbers: Bool

    /// Whether the minimap should be shown
    public let isMinimapVisible: Bool

    /// Whether word wrapping should be enabled
    public let enableWordWrap: Bool

    /// Recommended font size for the platform
    public let fontSize: CGFloat

    /// Recommended tab width in spaces
    public let tabWidth: Int

    /// Whether invisible characters should be displayed
    public let areInvisibleCharactersVisible: Bool

    /// Creates editor configuration hints with specified values
    /// - Parameters:
    ///   - showLineNumbers: Whether to show line numbers
    ///   - isMinimapVisible: Whether to show minimap
    ///   - enableWordWrap: Whether to enable word wrap
    ///   - fontSize: Font size to use
    ///   - tabWidth: Tab width in spaces
    ///   - areInvisibleCharactersVisible: Whether to show invisible characters
    public init(
        showLineNumbers: Bool,
        isMinimapVisible: Bool,
        enableWordWrap: Bool,
        fontSize: CGFloat,
        tabWidth: Int,
        areInvisibleCharactersVisible: Bool
    ) {
        self.showLineNumbers = showLineNumbers
        self.isMinimapVisible = isMinimapVisible
        self.enableWordWrap = enableWordWrap
        self.fontSize = fontSize
        self.tabWidth = tabWidth
        self.areInvisibleCharactersVisible = areInvisibleCharactersVisible
    }
}
