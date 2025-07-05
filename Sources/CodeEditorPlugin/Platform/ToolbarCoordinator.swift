import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif
import os.log

/// Coordinator responsible for creating and managing cross-platform toolbar items
///
/// `ToolbarCoordinator` provides unified toolbar management across different platforms,
/// ensuring appropriate toolbar items are available based on platform capabilities
/// and user interface idioms.
///
/// ## Overview
///
/// This coordinator abstracts the differences between:
/// - macOS: Full-featured toolbar with extensive options
/// - iOS iPad: Rich toolbar with most desktop features
/// - iOS iPhone: Simplified toolbar with essential features only
/// - Mac Catalyst: Desktop-style toolbar with touch considerations
///
/// ## Features
///
/// - **Platform-Adaptive**: Automatically adjusts toolbar based on platform
/// - **Capability-Aware**: Only shows items for supported features
/// - **Accessibility**: Ensures all toolbar items are properly accessible
/// - **Customizable**: Allows for custom toolbar configurations
///
/// ## Example Usage
///
/// ```swift
/// let coordinator = ToolbarCoordinator.shared
/// 
/// // Get platform-appropriate toolbar items
/// let items = coordinator.createToolbarItems()
/// 
/// // Create custom toolbar for specific context
/// let editingItems = coordinator.createEditingToolbar()
/// 
/// // Check if toolbar should be shown
/// let shouldShow = coordinator.shouldShowToolbar()
/// ```
///
/// - SeeAlso: ``CrossPlatformCoordinator`` for overall coordination
/// - SeeAlso: ``PlatformCapabilities`` for feature detection
@MainActor
public final class ToolbarCoordinator: ObservableObject {
    public static let shared = ToolbarCoordinator()
    
    private let logger = Logger(subsystem: "CodeEditorPlugin", category: "ToolbarCoordinator")
    private let capabilities = PlatformCapabilities.shared
    
    // MARK: - Initialization
    
    private init() {
        logger.debug("ToolbarCoordinator initialized")
    }
    
    // MARK: - Public Methods
    
    /// Create platform-appropriate toolbar items
    ///
    /// This method generates a set of toolbar items based on the current platform
    /// and available capabilities.
    ///
    /// - Returns: Array of toolbar items appropriate for the current platform
    public func createToolbarItems() -> [ToolbarItem] {
        var items: [ToolbarItem] = []
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        items = createMacOSToolbar()
        #else
        items = createIOSToolbar()
        #endif
        
        logger.debug("Created \(items.count) toolbar items for current platform")
        return items
    }
    
    /// Create editing-focused toolbar items
    ///
    /// Returns a minimal set of toolbar items focused on text editing operations.
    ///
    /// - Returns: Array of essential editing toolbar items
    public func createEditingToolbar() -> [ToolbarItem] {
        var items: [ToolbarItem] = []
        
        // Universal editing actions
        items.append(ToolbarItem(
            id: "undo",
            title: "Undo",
            icon: "arrow.uturn.backward",
            action: .custom { }
        ))
        
        items.append(ToolbarItem(
            id: "redo",
            title: "Redo", 
            icon: "arrow.uturn.forward",
            action: .custom { }
        ))
        
        items.append(ToolbarItem(
            id: "find",
            title: "Find",
            icon: "magnifyingglass",
            action: .find
        ))
        
        // Platform-specific additions
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        items.append(ToolbarItem(
            id: "replace",
            title: "Replace",
            icon: "arrow.left.arrow.right",
            action: .replace
        ))
        #else
        // On iOS, only add replace on iPad
        #if canImport(UIKit)
        if UIDevice.current.userInterfaceIdiom == .pad {
            items.append(ToolbarItem(
                id: "replace",
                title: "Replace",
                icon: "arrow.left.arrow.right",
                action: .replace
            ))
        }
        #endif
        #endif
        
        return items
    }
    
    /// Create debugging/development toolbar items
    ///
    /// Returns toolbar items useful for debugging and development tasks.
    ///
    /// - Returns: Array of development-focused toolbar items
    public func createDevelopmentToolbar() -> [ToolbarItem] {
        // Development toolbar is available on all platforms
        // Individual items check their own capabilities
        
        var items: [ToolbarItem] = []
        
        items.append(ToolbarItem(
            id: "symbols",
            title: "Symbols",
            icon: "list.bullet.indent",
            action: .showSymbols
        ))
        
        items.append(ToolbarItem(
            id: "format",
            title: "Format",
            icon: "text.alignleft",
            action: .format
        ))
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS gets additional development tools
        items.append(ToolbarItem(
            id: "console",
            title: "Console",
            icon: "terminal",
            action: .custom { }
        ))
        
        items.append(ToolbarItem(
            id: "debugger",
            title: "Debugger",
            icon: "ladybug",
            action: .custom { }
        ))
        #endif
        
        return items
    }
    
    /// Check if toolbar should be shown on current platform
    ///
    /// - Returns: True if toolbar is appropriate for the current platform
    public func shouldShowToolbar() -> Bool {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return true // Always show toolbar on macOS
        #else
        // On iOS, show toolbar based on device and available space
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
        #endif
    }
    
    /// Get recommended toolbar style for current platform
    ///
    /// - Returns: Platform-appropriate toolbar style identifier
    public func recommendedToolbarStyle() -> String {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return "unified"
        #else
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .pad ? "prominent" : "compact"
        #else
        return "compact"
        #endif
        #endif
    }
    
    /// Check if specific toolbar item should be enabled
    ///
    /// - Parameter itemId: The identifier of the toolbar item
    /// - Returns: True if the item should be enabled
    public func isToolbarItemEnabled(_ itemId: String) -> Bool {
        switch itemId {
        case "find", "undo", "redo":
            return true // Always available
        case "replace":
            return capabilities.isFeatureAvailable(.findReplace)

        case "symbols":
            return capabilities.isFeatureAvailable(.symbolNavigation)

        case "format":
            return true // Code formatting is always available
        case "console", "debugger":
            return capabilities.currentPlatform == .macOS // Development tools only on macOS
        default:
            return true
        }
    }
    
    // MARK: - Platform-Specific Implementation
    
    private func createMacOSToolbar() -> [ToolbarItem] {
        var items: [ToolbarItem] = []
        
        // Full toolbar on macOS
        items.append(ToolbarItem(
            id: "find",
            title: "Find",
            icon: "magnifyingglass",
            action: .find
        ))
        
        items.append(ToolbarItem(
            id: "replace",
            title: "Replace",
            icon: "arrow.left.arrow.right",
            action: .replace
        ))
        
        items.append(ToolbarItem(
            id: "symbol",
            title: "Symbols",
            icon: "list.bullet.indent",
            action: .showSymbols
        ))
        
        items.append(ToolbarItem(
            id: "format",
            title: "Format",
            icon: "text.alignleft",
            action: .format
        ))
        
        // Additional macOS-specific items
        items.append(ToolbarItem(
            id: "minimap",
            title: "Minimap",
            icon: "map",
            action: .custom { }
        ))
        
        items.append(ToolbarItem(
            id: "navigator",
            title: "Navigator",
            icon: "sidebar.left",
            action: .custom { }
        ))
        
        logger.debug("Created macOS toolbar with \(items.count) items")
        return items
    }
    
    private func createIOSToolbar() -> [ToolbarItem] {
        var items: [ToolbarItem] = []
        
        // Essential items for all iOS devices
        items.append(ToolbarItem(
            id: "find",
            title: "Find",
            icon: "magnifyingglass",
            action: .find
        ))
        
        // iPad gets additional features
        #if canImport(UIKit)
        if UIDevice.current.userInterfaceIdiom == .pad {
            items.append(ToolbarItem(
                id: "replace",
                title: "Replace",
                icon: "arrow.left.arrow.right",
                action: .replace
            ))
            
            items.append(ToolbarItem(
                id: "symbol",
                title: "Symbols",
                icon: "list.bullet.indent",
                action: .showSymbols
            ))
            
            items.append(ToolbarItem(
                id: "format",
                title: "Format",
                icon: "text.alignleft",
                action: .format
            ))
        }
        #endif
        
        // iPhone gets minimal toolbar
        #if canImport(UIKit)
        if UIDevice.current.userInterfaceIdiom == .phone {
            items.append(ToolbarItem(
                id: "share",
                title: "Share",
                icon: "square.and.arrow.up",
                action: .custom { }
            ))
        }
        #endif
        
        #if canImport(UIKit)
        logger.debug("Created iOS toolbar with \(items.count) items for \(UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone")")
        #else
        logger.debug("Created iOS toolbar with \(items.count) items")
        #endif
        return items
    }
    
    // MARK: - Toolbar Item Factories
    
    /// Create a custom toolbar item with specific configuration
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the item
    ///   - title: Display title
    ///   - icon: System icon name
    ///   - action: Action to perform when activated
    /// - Returns: Configured toolbar item
    public func createCustomToolbarItem(
        id: String,
        title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> ToolbarItem {
        ToolbarItem(
            id: id,
            title: title,
            icon: icon,
            action: .custom(action: action)
        )
    }
    
    /// Create a spacer toolbar item for layout purposes
    ///
    /// - Returns: Spacer toolbar item
    public func createSpacerItem() -> ToolbarItem {
        ToolbarItem(
            id: "spacer",
            title: "",
            icon: "",
            action: .custom { }
        )
    }
    
    /// Create a flexible space toolbar item
    ///
    /// - Returns: Flexible space toolbar item
    public func createFlexibleSpaceItem() -> ToolbarItem {
        ToolbarItem(
            id: "flexible-space",
            title: "",
            icon: "",
            action: .custom { }
        )
    }
}

// MARK: - Toolbar Configuration

extension ToolbarCoordinator {
    /// Configuration options for toolbar appearance and behavior
    public struct ToolbarConfiguration {
        public var showTitles: Bool = true
        public var allowCustomization: Bool = true
        public var compactMode: Bool = false
        public var primaryItems: [String] = []
        public var secondaryItems: [String] = []
        
        public init() {}
    }
    
    /// Get default toolbar configuration for current platform
    ///
    /// - Returns: Platform-appropriate toolbar configuration
    public func defaultConfiguration() -> ToolbarConfiguration {
        var config = ToolbarConfiguration()
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS defaults
        config.showTitles = true
        config.allowCustomization = true
        config.compactMode = false
        config.primaryItems = ["find", "replace", "symbol", "format"]
        #else
        // iOS defaults
        #if canImport(UIKit)
        config.showTitles = UIDevice.current.userInterfaceIdiom == .pad
        config.allowCustomization = false
        config.compactMode = UIDevice.current.userInterfaceIdiom == .phone
        config.primaryItems = UIDevice.current.userInterfaceIdiom == .pad ? 
            ["find", "replace", "symbol"] : ["find", "share"]
        #else
        config.showTitles = false
        config.allowCustomization = false
        config.compactMode = true
        config.primaryItems = ["find"]
        #endif
        #endif
        
        return config
    }
    
    /// Apply configuration to toolbar items
    ///
    /// - Parameters:
    ///   - items: Toolbar items to configure
    ///   - configuration: Configuration to apply
    /// - Returns: Configured toolbar items
    public func applyConfiguration(
        to items: [ToolbarItem],
        with configuration: ToolbarConfiguration
    ) -> [ToolbarItem] {
        var configuredItems = items
        
        // Filter based on primary/secondary items if specified
        if !configuration.primaryItems.isEmpty {
            configuredItems = configuredItems.filter { item in
                configuration.primaryItems.contains(item.id)
            }
        }
        
        // Apply compact mode adjustments
        if configuration.compactMode {
            // In compact mode, limit to essential items
            configuredItems = Array(configuredItems.prefix(3))
        }
        
        return configuredItems
    }
}
