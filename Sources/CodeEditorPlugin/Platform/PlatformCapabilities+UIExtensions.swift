import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - UI Capabilities

extension PlatformCapabilities {
    /// User interface capabilities and features
    public struct UICapabilities {
        /// Whether minimap view is supported and practical
        public let supportsMinimap: Bool

        /// Whether multiple windows can be opened simultaneously
        public let supportsMultipleWindows: Bool

        /// Whether Touch Bar is available (macOS with Touch Bar only)
        public let supportsTouchBar: Bool

        /// Whether context menus are supported
        public let supportsContextMenus: Bool

        /// Whether vibrant/translucent materials are available
        public let supportsVibrantMaterials: Bool

        /// Whether floating panels/windows are supported
        public let supportsFloatingPanels: Bool

        /// Recommended layout style for the current platform
        public let recommendedLayoutStyle: LayoutStyle
    }

    /// Recommended layout styles for different platforms
    public enum LayoutStyle {
        /// Full desktop with multiple panels and advanced features
        case desktop
        /// Tablet-optimized with sidebars and touch-friendly controls  
        case tablet
        /// Mobile-first single-pane with simplified interface
        case mobile
        /// Adaptive layout that changes based on size class
        case adaptive
    }

    /// Get comprehensive UI capabilities
    ///
    /// This computed property provides a complete overview of UI features
    /// available on the current platform, enabling adaptive interface design.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let ui = capabilities.uiCapabilities
    /// 
    /// // Configure UI based on capabilities
    /// if ui.supportsMinimap {
    ///     showMinimapToggle()
    /// }
    /// 
    /// if ui.supportsFloatingPanels {
    ///     enableDetachablePanels()
    /// }
    /// 
    /// // Apply recommended layout
    /// switch ui.recommendedLayoutStyle {
    /// case .desktop:
    ///     setupDesktopLayout()
    /// case .tablet:
    ///     setupTabletLayout()
    /// case .mobile:
    ///     setupMobileLayout()
    /// case .adaptive:
    ///     setupAdaptiveLayout()
    /// }
    /// ```
    ///
    /// - Returns: Comprehensive UI capability information
    public var uiCapabilities: UICapabilities {
        let layoutStyle: LayoutStyle

        switch currentPlatform {
        case .macOS:
            layoutStyle = .desktop

        case .iOS:
            #if canImport(UIKit)
            layoutStyle = UIDevice.current.userInterfaceIdiom == .pad ? .tablet : .mobile
            #else
            layoutStyle = .adaptive
            #endif
        }

        return UICapabilities(
            supportsMinimap: supportsMinimap,
            supportsMultipleWindows: supportsMultipleWindows,
            supportsTouchBar: supportsTouchBar,
            supportsContextMenus: supportsContextMenus,
            supportsVibrantMaterials: supportsVibrantMaterials,
            supportsFloatingPanels: supportsFloatingPanels,
            recommendedLayoutStyle: layoutStyle
        )
    }

    /// Whether minimap view is supported
    ///
    /// Minimap provides a zoomed-out overview of the entire document,
    /// useful for navigation in large files.
    ///
    /// ## Platform Support
    /// - **macOS**: Not currently implemented
    /// - **iOS**: Supported with touch navigation
    /// - **Catalyst**: Supported with hybrid interaction
    ///
    /// - Returns: True if minimap is available
    public var supportsMinimap: Bool {
        // Currently only implemented for iOS platforms
        currentPlatform == .iOS
    }

    /// Whether multiple windows are supported
    ///
    /// Multiple window support allows users to have several editor
    /// instances open simultaneously.
    ///
    /// ## Platform Support
    /// - **macOS**: Full multi-window support
    /// - **iPadOS**: Scene-based multiple windows (13.0+)
    /// - **iOS iPhone**: Not supported
    /// - **Catalyst**: Full multi-window support
    ///
    /// - Returns: True if multiple windows are supported
    public var supportsMultipleWindows: Bool {
        switch currentPlatform {
        case .macOS:
            return true

        case .iOS:
            #if canImport(UIKit)
            // iPadOS supports multiple windows via scenes
            return UIDevice.current.userInterfaceIdiom == .pad &&
                   systemVersionComponents.major >= 13
            #else
            return false
            #endif
        }
    }

    /// Whether Touch Bar is supported
    ///
    /// Touch Bar provides contextual controls on supported MacBook models.
    ///
    /// ## Device Support
    /// - **MacBook Pro**: 2016-2020 models with Touch Bar
    /// - **Other Macs**: Not supported
    /// - **iOS/Catalyst**: Not applicable
    ///
    /// - Returns: True if Touch Bar is available
    public var supportsTouchBar: Bool {
        #if canImport(AppKit)
        return true // Runtime detection would be more accurate
        #else
        return false
        #endif
    }

    /// Whether context menus are supported
    ///
    /// Context menus provide quick access to relevant actions
    /// via right-click or long-press gestures.
    ///
    /// ## Platform Support
    /// - **macOS**: Full context menu support
    /// - **iOS**: Long-press context menus (13.0+)
    /// - **Catalyst**: Both right-click and long-press support
    ///
    /// - Returns: True if context menus are available
    public var supportsContextMenus: Bool {
        #if canImport(AppKit)
        return true
        #elseif canImport(UIKit)
        // iOS 13.0+ supports context menus
        return systemVersionComponents.major >= 13
        #else
        return false
        #endif
    }

    /// Whether vibrant/translucent materials are supported
    ///
    /// Vibrant materials provide visual depth and system integration
    /// through translucency and blur effects.
    ///
    /// ## Platform Support
    /// - **macOS**: NSVisualEffectView materials
    /// - **iOS**: UIVisualEffectView materials (13.0+)
    /// - **Catalyst**: Inherits iOS support
    ///
    /// - Returns: True if vibrant materials are available
    public var supportsVibrantMaterials: Bool {
        #if canImport(AppKit)
        return true
        #elseif canImport(UIKit)
        // iOS 13.0+ supports modern materials
        return systemVersionComponents.major >= 13
        #else
        return false
        #endif
    }

    /// Whether floating/detachable panels are supported
    ///
    /// Floating panels allow users to detach sections of the interface
    /// for flexible workspace organization.
    ///
    /// ## Platform Support
    /// - **macOS**: Full floating window support
    /// - **iPadOS**: Limited floating support via scenes
    /// - **iOS iPhone**: Not supported
    /// - **Catalyst**: Full floating window support
    ///
    /// - Returns: True if floating panels are supported
    public var supportsFloatingPanels: Bool {
        switch currentPlatform {
        case .macOS:
            return true

        case .iOS:
            #if canImport(UIKit)
            // Only iPad supports floating panels
            return UIDevice.current.userInterfaceIdiom == .pad
            #else
            return false
            #endif
        }
    }

    /// Whether the device has a notch or dynamic island
    ///
    /// Devices with notches or dynamic islands require special consideration
    /// for UI layout to avoid obscured content.
    ///
    /// ## Detection Method
    /// - Checks safe area insets for unusual top values
    /// - Indicates presence of notch, dynamic island, or similar features
    ///
    /// - Returns: True if device has display cutouts
    public var hasNotch: Bool {
        #if canImport(UIKit)
        if #available(iOS 13.0, *) {
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows.first else { return false }
            return window.safeAreaInsets.top > 20
        } else {
            guard let window = UIApplication.shared.keyWindow else { return false }
            return window.safeAreaInsets.top > 20
        }
        #else
        return false
        #endif
    }

    /// Get recommended UI configuration for optimal UX
    ///
    /// This method provides platform-specific recommendations for UI
    /// configuration based on available features and capabilities.
    ///
    /// ## Configuration Areas
    /// - **Layout style**: Navigation and panel organization
    /// - **Visual effects**: Materials and blur effects
    /// - **Panel behavior**: Detachable vs fixed panels
    /// - **Context menus**: Interaction patterns
    ///
    /// - Returns: Recommended UI configuration
    public func recommendedUIConfiguration() -> UIConfiguration {
        var config = UIConfiguration()

        // Platform-specific base configuration
        switch currentPlatform {
        case .macOS:
            config.layoutStyle = .desktop
            config.enableVibrantMaterials = supportsVibrantMaterials
            config.enableFloatingPanels = true
            config.enableTouchBar = supportsTouchBar
            config.showFullToolbar = true

        case .iOS:
            #if canImport(UIKit)
            if UIDevice.current.userInterfaceIdiom == .pad {
                config.layoutStyle = .tablet
                config.enableFloatingPanels = true
                config.showFullToolbar = true
            } else {
                config.layoutStyle = .mobile
                config.enableFloatingPanels = false
                config.showFullToolbar = false
            }
            #else
            config.layoutStyle = .mobile
            #endif

            config.enableVibrantMaterials = supportsVibrantMaterials
            config.respectSafeAreas = true
        }

        // Feature-based adjustments
        if supportsMinimap {
            config.enableMinimap = true
        }

        if supportsContextMenus {
            config.enableRichContextMenus = true
        }

        // Accessibility and Dynamic Type adjustments
        #if canImport(UIKit)
        if UIAccessibility.isVoiceOverRunning {
            config.simplifyInterface = true
            config.enableFloatingPanels = false
        }
        #endif

        return config
    }

    /// Configuration for UI features and behavior
    public struct UIConfiguration {
        /// Primary layout style for the interface
        public var layoutStyle: LayoutStyle = .adaptive

        /// Whether to enable vibrant/translucent materials
        public var enableVibrantMaterials: Bool = false

        /// Whether to enable floating/detachable panels
        public var enableFloatingPanels: Bool = false

        /// Whether to enable Touch Bar integration
        public var enableTouchBar: Bool = false

        /// Whether to enable minimap view
        public var enableMinimap: Bool = false

        /// Whether to show full toolbar or compact version
        public var showFullToolbar: Bool = true

        /// Whether to enable rich context menus
        public var enableRichContextMenus: Bool = false

        /// Whether to respect safe areas for notched devices
        public var respectSafeAreas: Bool = true

        /// Whether to simplify interface for accessibility
        public var simplifyInterface: Bool = false

        /// Whether to enable hybrid mouse/touch interaction (Catalyst)
        public var enableHybridInteraction: Bool = false

        /// Creates default UI configuration for the current platform
        public init() {}
    }

    // MARK: - Layout Utilities

    /// Get safe layout margins for current device
    ///
    /// Provides recommended margins that account for device-specific
    /// features like notches, safe areas, and platform conventions.
    ///
    /// - Returns: Recommended layout margins
    public func safeLayoutMargins() -> NSDirectionalEdgeInsets {
        #if canImport(UIKit)
        // Get current safe area insets if available
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first {
            let safeInsets = window.safeAreaInsets
            return NSDirectionalEdgeInsets(
                top: max(safeInsets.top, 8),
                leading: max(safeInsets.left, 16),
                bottom: max(safeInsets.bottom, 8),
                trailing: max(safeInsets.right, 16)
            )
        }
        #endif

        // Fallback margins based on platform
        switch currentPlatform {
        case .macOS:
            return NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)

        case .iOS:
            return NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        }
    }

    /// Get recommended minimum touch target size
    ///
    /// Returns the minimum touch target size for interactive elements
    /// based on platform guidelines and accessibility requirements.
    ///
    /// - Returns: Minimum touch target size in points
    public func minimumTouchTargetSize() -> CGSize {
        switch currentPlatform {
        case .macOS:
            return CGSize(width: 24, height: 24) // Mouse precision

        case .iOS:
            return CGSize(width: 44, height: 44) // iOS HIG

        }
    }
}
