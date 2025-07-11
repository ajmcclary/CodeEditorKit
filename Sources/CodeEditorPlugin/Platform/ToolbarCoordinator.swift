import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

/// Coordinator responsible for creating and managing platform-specific toolbar items
///
/// `ToolbarCoordinator` provides unified toolbar management across different platforms,
/// creating appropriate toolbar items and handling their configuration based on
/// platform capabilities and conventions.
///
/// ## Overview
///
/// This coordinator abstracts toolbar differences between:
/// - macOS: Full desktop toolbar with rich customization
/// - iOS: Compact toolbar with essential actions
/// - Mac Catalyst: Hybrid approach supporting both paradigms
///
/// ## Features
///
/// - **Smart Item Selection**: Automatically selects appropriate items per platform
/// - **Keyboard Shortcuts**: Configures shortcuts where supported
/// - **Adaptive Layouts**: Adjusts for device size and orientation
/// - **Custom Actions**: Supports both built-in and custom toolbar actions
///
/// ## Example Usage
///
/// ```swift
/// let coordinator = ToolbarCoordinator()
/// 
/// // Get platform-appropriate toolbar items
/// let items = coordinator.createToolbarItems()
/// 
/// // Create specific toolbar types
/// let editingTools = coordinator.createEditingToolbar()
/// let navigationTools = coordinator.createNavigationToolbar()
/// ```
///
/// - SeeAlso: ``CrossPlatformCoordinator`` for overall coordination
/// - SeeAlso: ``ToolbarItem`` for toolbar item structure
@MainActor
public final class ToolbarCoordinator: ObservableObject {
    /// Shared instance for backward compatibility
    /// - Warning: This property is deprecated. Use dependency injection instead.
    @available(*, deprecated, message: "Use dependency injection instead of the singleton pattern")
    public static let shared = ToolbarCoordinator()
    
    private let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "ToolbarCoordinator")
    private let capabilities: PlatformCapabilities
    
    // MARK: - Initialization
    
    /// Creates a new ToolbarCoordinator instance
    /// - Parameter capabilities: Platform capabilities provider (defaults to shared instance)
    public init(capabilities: PlatformCapabilities? = nil) {
        self.capabilities = capabilities ?? PlatformCapabilities.shared
        logger.debug("ToolbarCoordinator initialized")
    }
    
    // MARK: - Public Methods
    
    /// Create platform-appropriate toolbar items
    ///
    /// This method returns a default set of toolbar items optimized for the current platform.
    /// The selection and ordering of items is based on platform conventions and available space.
    ///
    /// - Returns: Array of toolbar items appropriate for the current platform
    public func createToolbarItems() -> [ToolbarItem] {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return createMacOSToolbar()
        #elseif targetEnvironment(macCatalyst)
        return createCatalystToolbar()
        #else
        return createIOSToolbar()
        #endif
    }
    
    /// Configure a toolbar item with platform-specific attributes
    ///
    /// - Parameters:
    ///   - item: The toolbar item to configure
    ///   - view: Optional view for context-specific configuration
    /// - Returns: Configured toolbar item
    public func configureToolbarItem(_ item: ToolbarItem, for view: PlatformView? = nil) -> ToolbarItem {
        let configuredItem = item
        
        // Platform-specific configuration
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS supports full keyboard shortcuts
        #elseif canImport(UIKit)
        // iOS may need different icons or actions
        if view != nil && UIDevice.current.userInterfaceIdiom == .phone {
            // Adjust for compact space on iPhone
        }
        #endif
        
        return configuredItem
    }
    
    /// Create editing-focused toolbar items
    ///
    /// - Returns: Array of essential editing toolbar items
    public func createEditingToolbar() -> [ToolbarItem] {
        var items: [ToolbarItem] = []
        
        // Universal editing actions
        items.append(ToolbarItem(
            title: "Undo",
            icon: "arrow.uturn.backward",
            action: .custom(id: "undo"),
            id: "undo"
        ))
        
        items.append(ToolbarItem(
            title: "Redo", 
            icon: "arrow.uturn.forward",
            action: .custom(id: "redo"),
            id: "redo"
        ))
        
        items.append(ToolbarItem(
            title: "Find",
            icon: "magnifyingglass",
            action: .find,
            id: "find"
        ))
        
        // Platform-specific additions
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        items.append(ToolbarItem(
            title: "Replace",
            icon: "arrow.left.arrow.right",
            action: .replace,
            id: "replace"
        ))
        #elseif canImport(UIKit)
        // Add replace only on iPad
        if UIDevice.current.userInterfaceIdiom == .pad {
            items.append(ToolbarItem(
                title: "Replace",
                icon: "arrow.left.arrow.right",
                action: .replace,
                id: "replace"
            ))
        }
        #endif
        
        return items
    }
    
    /// Create navigation-focused toolbar items
    ///
    /// - Returns: Array of navigation toolbar items
    public func createNavigationToolbar() -> [ToolbarItem] {
        var items: [ToolbarItem] = []
        
        items.append(ToolbarItem(
            title: "Symbols",
            icon: "list.bullet.indent",
            action: .showSymbols,
            id: "symbols"
        ))
        
        items.append(ToolbarItem(
            title: "Format",
            icon: "text.alignleft",
            action: .format,
            id: "format"
        ))
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS gets additional development tools
        items.append(ToolbarItem(
            title: "Console",
            icon: "terminal",
            action: .custom(id: "console"),
            id: "console"
        ))
        
        items.append(ToolbarItem(
            title: "Debugger",
            icon: "ladybug",
            action: .custom(id: "debugger"),
            id: "debugger"
        ))
        #endif
        
        return items
    }
    
    /// Create view customization toolbar items
    ///
    /// - Returns: Array of view customization toolbar items
    public func createViewToolbar() -> [ToolbarItem] {
        var items: [ToolbarItem] = []
        
        items.append(ToolbarItem(
            title: "Toggle Line Numbers",
            icon: "number",
            action: .toggleLineNumbers,
            id: "toggle-line-numbers"
        ))
        
        if capabilities.isFeatureAvailable(.minimap) {
            items.append(ToolbarItem(
                title: "Toggle Minimap",
                icon: "map",
                action: .toggleMinimap,
                id: "toggle-minimap"
            ))
        }
        
        return items
    }
    
    /// Validate if a toolbar action is available on the current platform
    ///
    /// - Parameter action: The toolbar action to validate
    /// - Returns: True if the action is available
    public func isActionAvailable(_ action: ToolbarItem.ToolbarAction) -> Bool {
        switch action {
        case .find:
            return true // Available on all platforms
            
        case .replace:
            #if canImport(UIKit)
            // Replace is available on iPad and Mac Catalyst
            return UIDevice.current.userInterfaceIdiom == .pad || capabilities.currentPlatform == .catalyst
            #else
            return true
            #endif
            
        case .showSymbols:
            return capabilities.isFeatureAvailable(.symbolNavigation)
            
        case .format:
            return capabilities.isFeatureAvailable(.autoIndent)
            
        case .toggleLineNumbers:
            return true
            
        case .toggleMinimap:
            return capabilities.isFeatureAvailable(.minimap)
            
        case .custom:
            return true
        }
    }
    
    // MARK: - Private Methods
    
    private func createMacOSToolbar() -> [ToolbarItem] {
        var items: [ToolbarItem] = []
        
        // Full toolbar on macOS
        items.append(ToolbarItem(
            title: "Find",
            icon: "magnifyingglass",
            action: .find,
            id: "find"
        ))
        
        items.append(ToolbarItem(
            title: "Replace",
            icon: "arrow.left.arrow.right",
            action: .replace,
            id: "replace"
        ))
        
        items.append(ToolbarItem(
            title: "Symbols",
            icon: "list.bullet.indent",
            action: .showSymbols,
            id: "symbol"
        ))
        
        items.append(ToolbarItem(
            title: "Format",
            icon: "text.alignleft",
            action: .format,
            id: "format"
        ))
        
        // Additional macOS-specific items
        items.append(ToolbarItem(
            title: "Minimap",
            icon: "map",
            action: .custom(id: "minimap"),
            id: "minimap"
        ))
        
        items.append(ToolbarItem(
            title: "Navigator",
            icon: "sidebar.left",
            action: .custom(id: "navigator"),
            id: "navigator"
        ))
        
        return items
    }
    
    #if canImport(UIKit)
    private func createIOSToolbar() -> [ToolbarItem] {
        var items: [ToolbarItem] = []
        
        // Essential items for all iOS devices
        items.append(ToolbarItem(
            title: "Find",
            icon: "magnifyingglass",
            action: .find,
            id: "find"
        ))
        
        // iPad gets more items
        if UIDevice.current.userInterfaceIdiom == .pad {
            items.append(ToolbarItem(
                title: "Replace",
                icon: "arrow.left.arrow.right",
                action: .replace,
                id: "replace"
            ))
            
            items.append(ToolbarItem(
                title: "Symbols",
                icon: "list.bullet.indent",
                action: .showSymbols,
                id: "symbol"
            ))
            
            items.append(ToolbarItem(
                title: "Format",
                icon: "text.alignleft",
                action: .format,
                id: "format"
            ))
        }
        
        // iPhone gets compact toolbar
        if UIDevice.current.userInterfaceIdiom == .phone {
            items.append(ToolbarItem(
                title: "Share",
                icon: "square.and.arrow.up",
                action: .custom(id: "share"),
                id: "share"
            ))
        }
        
        return items
    }
    
    private func createCatalystToolbar() -> [ToolbarItem] {
        // Mac Catalyst gets a hybrid approach
        // Similar to macOS but respects iOS constraints
        createMacOSToolbar()
    }
    #endif
    
    /// Create a custom toolbar item
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the item
    ///   - title: Display title
    ///   - icon: SF Symbol name
    ///   - action: Closure to execute when tapped
    /// - Returns: Configured toolbar item
    public func createCustomToolbarItem(
        id: String,
        title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> ToolbarItem {
        // Note: The action closure parameter is not used since ToolbarItem.ToolbarAction
        // uses an id-based system. The actual action handling is done in executeAction.
        _ = action
        
        return ToolbarItem(
            title: title,
            icon: icon,
            action: .custom(id: id),
            id: id
        )
    }
    
    /// Create a spacer toolbar item
    /// - Returns: Fixed space toolbar item
    public func createSpacerItem() -> ToolbarItem {
        ToolbarItem(
            title: "",
            icon: "",
            action: .custom(id: "spacer"),
            id: "spacer"
        )
    }
    
    /// Create a flexible space toolbar item
    /// - Returns: Flexible space toolbar item
    public func createFlexibleSpaceItem() -> ToolbarItem {
        ToolbarItem(
            title: "",
            icon: "",
            action: .custom(id: "flexible-space"),
            id: "flexible-space"
        )
    }
}

// MARK: - Toolbar Actions Extension

extension ToolbarCoordinator {
    /// Execute a toolbar action with the associated text view
    ///
    /// - Parameters:
    ///   - action: The toolbar action to execute
    ///   - textView: The text view to perform the action on
    public func executeAction(_ action: ToolbarItem.ToolbarAction, on textView: CodeEditorView) {
        switch action {
        case .find:
            // Trigger find UI
            logger.debug("Find action triggered")
            
        case .replace:
            // Trigger replace UI
            logger.debug("Replace action triggered")
            
        case .showSymbols:
            // Show symbol navigator
            logger.debug("Show symbols action triggered")
            
        case .format:
            // Format code
            logger.debug("Format action triggered")
            
        case .toggleLineNumbers:
            // Toggle line numbers
            var config = textView.configuration
            config.display.isLineNumbersEnabled.toggle()
            textView.configuration = config
            logger.debug("Toggle line numbers action triggered")
            
        case .toggleMinimap:
            // Toggle minimap
            var config = textView.configuration
            config.display.showMinimap.toggle()
            textView.configuration = config
            logger.debug("Toggle minimap action triggered")
            
        case let .custom(id):
            // Handle custom action
            logger.debug("Custom action triggered: \(id)")
        }
    }
}

// MARK: - SwiftUI Integration

#if canImport(SwiftUI)
extension ToolbarCoordinator {
    /// Create SwiftUI toolbar content
    ///
    /// - Parameter textView: The associated text view for actions
    /// - Returns: SwiftUI toolbar content
    @ViewBuilder
    public func toolbarContent(for textView: CodeEditorView) -> some View {
        ForEach(createToolbarItems()) { item in
            Button(action: {
                self.executeAction(item.action, on: textView)
            }) {
                Label(item.title, systemImage: item.icon)
            }
            .keyboardShortcut(
                item.keyboardShortcut.flatMap { shortcut in
                    shortcut.key.first.map { KeyboardShortcut(KeyEquivalent($0)) }
                }
            )
        }
    }
}
#endif
