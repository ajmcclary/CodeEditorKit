import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif
import os.log

/// Main coordinator for ensuring cross-platform feature parity and smooth operation
///
/// `CrossPlatformCoordinator` serves as the central coordination point for cross-platform
/// functionality, delegating specialized tasks to focused coordinators while maintaining
/// overall system coherence.
///
/// ## Architecture
///
/// The coordinator follows a delegation pattern where specialized coordinators handle
/// specific domains:
/// - ``InputCoordinator``: Handles input events (keyboard, mouse, touch, pencil)
/// - ``ToolbarCoordinator``: Manages toolbar creation and configuration
/// - ``ContextMenuCoordinator``: Handles context menu creation and actions
///
/// ## Responsibilities
///
/// - Platform-specific adjustments and optimizations
/// - Capability detection and feature availability
/// - Text view optimization and configuration
/// - Notification and observer management
/// - Platform abstraction coordination
///
/// - SeeAlso: ``InputCoordinator`` for input handling
/// - SeeAlso: ``ToolbarCoordinator`` for toolbar management
/// - SeeAlso: ``ContextMenuCoordinator`` for context menu handling
@MainActor
public class CrossPlatformCoordinator: ObservableObject {
    // MARK: - Singleton
    
    public static let shared = CrossPlatformCoordinator()
    
    // MARK: - Properties
    
    internal let logger = Logger(subsystem: "CodeEditorPlugin", category: "CrossPlatformCoordinator")
    internal let capabilities = PlatformCapabilities.shared
    
    /// Specialized coordinators for focused responsibilities
    public let inputCoordinator = InputCoordinator.shared
    public let toolbarCoordinator = ToolbarCoordinator.shared
    public let contextMenuCoordinator = ContextMenuCoordinator.shared
    
    /// Platform-specific adjustments
    @Published public private(set) var platformAdjustments = PlatformAdjustments()
    
    /// Thread-safe observer storage
    private let observerStore = ObserverStore()
    
    // MARK: - Types
    
    /// Platform-specific adjustments
    public struct PlatformAdjustments {
        // Font adjustments
        public var defaultFontSize: CGFloat = {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            return 12.0
            #else
            return 14.0 // Larger for touch
            #endif
        }()
        
        // Spacing adjustments
        public var lineSpacing: CGFloat = {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            return 1.2
            #else
            return 1.4 // More spacing for touch
            #endif
        }()
        
        public var gutterWidth: CGFloat = {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            return 40.0
            #else
            return 50.0 // Wider for touch targets
            #endif
        }()
        
        // Touch adjustments
        public var minimumTouchTargetSize: CGFloat = {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            return 24.0
            #else
            return 44.0 // iOS HIG recommendation
            #endif
        }()
        
        // Performance adjustments
        public var maxFileSize: Int = {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            return 10_000_000 // 10MB
            #else
            return 5_000_000 // 5MB for iOS
            #endif
        }()
        
        public var maxHighlightingLength: Int = {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            return 1_000_000
            #else
            return 500_000 // Less for iOS
            #endif
        }()
        
        // UI adjustments
        public var showMinimap: Bool = {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            return true
            #else
            return false // Not supported on iOS
            #endif
        }()
        
        public var enableMultiCursor: Bool {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            return true
            #else
            return false // Simplified for iOS to avoid actor isolation issues
            #endif
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        adjustFeaturesForPlatform()
        setupPlatformSpecificObservers()
    }
    
    deinit {
        // Additional cleanup for any observers not tracked in the array
        NotificationCenter.default.removeObserver(self)
        // Note: ObserverStore will clean up automatically in its own deinit
    }
    
    // MARK: - Public Methods
    
    /// Check if a specific feature is available on the current platform
    /// This method now fully delegates to PlatformCapabilities for unified capability detection
    public func isFeatureAvailable(_ feature: PlatformCapabilities.EditorFeature) -> Bool {
        capabilities.isFeatureAvailable(feature)
    }
    
    /// Get feature availability level (full, partial, or unavailable)
    public func getFeatureAvailability(_ feature: PlatformCapabilities.EditorFeature) -> PlatformCapabilities.FeatureAvailability {
        capabilities.getFeatureAvailability(feature)
    }
    
    /// Get recommended configuration for current platform
    public func recommendedConfiguration() -> EditorConfiguration {
        // Delegate to PlatformCapabilities for unified capability detection
        PlatformCapabilities.shared.recommendedConfiguration()
    }
    
    /// Apply platform-specific optimizations to a text view
    public func optimizeTextView(_ textView: CodeEditorView) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        optimizeForMacOS(textView)
        #else
        optimizeForIOS(textView)
        #endif
    }
    
    /// Create platform-appropriate toolbar items
    ///
    /// Delegates to the specialized ``ToolbarCoordinator`` for consistent toolbar management.
    ///
    /// - Returns: Array of toolbar items appropriate for the current platform
    public func createToolbarItems() -> [ToolbarItem] {
        toolbarCoordinator.createToolbarItems()
    }
    
    /// Handle platform-specific input events
    ///
    /// Delegates to the specialized ``InputCoordinator`` for consistent input handling.
    ///
    /// - Parameters:
    ///   - event: The platform input event to handle
    ///   - textView: The target text view
    /// - Returns: True if the event was handled, false otherwise
    public func handlePlatformInput(_ event: PlatformInputEvent, in textView: CodeEditorView) -> Bool {
        inputCoordinator.handleInput(event, in: textView)
    }
    
    /// Create cross-platform context menu using modern action-based API
    ///
    /// Delegates to the specialized ``ContextMenuCoordinator`` for consistent menu management.
    ///
    /// - Parameters:
    ///   - range: The text range associated with the menu
    ///   - textView: The target text view
    /// - Returns: Platform-appropriate context menu
    public func createContextMenu(for range: NSRange, in textView: CodeEditorView) -> PlatformContextMenu {
        contextMenuCoordinator.createContextMenu(for: range, in: textView)
    }
    
    // MARK: - Private Methods
    
    internal func adjustFeaturesForPlatform() {
        // Platform-specific adjustments are now handled by PlatformCapabilities
        // This method maintains runtime adjustments only
        
        #if canImport(UIKit)
        // Update platform adjustments based on runtime checks
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad gets larger touch targets
            platformAdjustments.minimumTouchTargetSize = 44.0
        }
        #endif
    }
    
    private func setupPlatformSpecificObservers() {
        // Remove any existing observers first
        removeObservers()
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        setupMacOSNotifications()
        #elseif canImport(UIKit)
        setupIOSNotifications()
        #endif
    }
    
    private func removeObservers() {
        observerStore.removeAllObservers()
    }
    
    /// Add observer to the thread-safe store
    internal func addObserver(_ observer: NSObjectProtocol) {
        observerStore.addObserver(observer)
    }
    
    // Platform-specific optimization is now in extensions:
    // - CrossPlatformCoordinator+AppKit.swift for macOS
    // - CrossPlatformCoordinator+UIKit.swift for iOS
    
    // Input handling is now delegated to InputCoordinator
    
    // MARK: - Helper Methods
    
    /// Update platform adjustments - internal method for extensions
    internal func updatePlatformAdjustments(_ update: (inout PlatformAdjustments) -> Void) {
        update(&platformAdjustments)
    }
    
    // iOS-specific helper methods moved to CrossPlatformCoordinator+UIKit.swift
    
    // MARK: - Common Actions
    
    @objc func undo() {
        logger.debug("Undo requested")
        // Implementation would perform undo
    }
    
    @objc func redo() {
        logger.debug("Redo requested")
        // Implementation would perform redo
    }
    
    @objc func find() {
        logger.debug("Find requested")
        // Implementation would show find UI
    }
    
    @objc func toggleComment() {
        logger.debug("Toggle comment requested")
        // Implementation would toggle comments
    }
    
    #if canImport(UIKit)
    @objc func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    #endif
    
    // Context menu actions are now handled by ContextMenuCoordinator
    
    // These methods are stubs and should be implemented as needed
    internal func selectNextOccurrence(in _: CodeEditorView) {
        logger.debug("selectNextOccurrence not yet implemented")
    }
    
    internal func selectLine(in _: CodeEditorView) {
        logger.debug("selectLine not yet implemented")
    }
    
    private func toggleComment(in _: CodeEditorView) {
        logger.debug("toggleComment not yet implemented")
    }
    
    internal func showFind(in _: CodeEditorView) {
        logger.debug("showFind not yet implemented")
    }
    
    /// Show context menu at default location
    ///
    /// - Parameter textView: The target text view
    internal func showContextMenu(in textView: CodeEditorView) {
        showContextMenu(at: CGPoint.zero, in: textView)
    }
    
    /// Show context menu at specified location
    ///
    /// Delegates to the specialized ``ContextMenuCoordinator`` for consistent menu handling.
    ///
    /// - Parameters:
    ///   - location: The location to show the menu
    ///   - textView: The target text view
    internal func showContextMenu(at location: CGPoint, in textView: CodeEditorView) {
        let menu = contextMenuCoordinator.createContextMenu(for: NSRange(), in: textView)
        contextMenuCoordinator.showContextMenu(menu, at: location, in: textView)
    }
    
    internal func startSelection(at _: CGPoint, in _: CodeEditorView) {
        // Start selection at location
    }
    
    /// Configure input handling for a text view
    ///
    /// Delegates to the specialized ``InputCoordinator`` for consistent input setup.
    ///
    /// - Parameter textView: The text view to configure
    private func configureInputHandling(for textView: CodeEditorView) {
        inputCoordinator.configureGestures(for: textView)
    }
}

// MARK: - Supporting Types

/// Platform input event
public enum PlatformInputEvent {
    case keyDown(key: String, modifiers: PlatformModifierFlags)
    case touch(touches: Set<AnyHashable>, phase: PlatformTouchPhase)
    case mouse(location: CGPoint, type: PlatformMouseEventType)
    case pencil(location: CGPoint, pressure: CGFloat, azimuth: CGFloat)
}

/// Platform modifier flags
public struct PlatformModifierFlags: OptionSet, Sendable {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let command = Self(rawValue: 1 << 0)
    public static let option = Self(rawValue: 1 << 1)
    public static let control = Self(rawValue: 1 << 2)
    public static let shift = Self(rawValue: 1 << 3)
}

/// Touch info wrapper
public struct TouchInfo {
    public let location: CGPoint
    public let previousLocation: CGPoint
    public let timestamp: TimeInterval
}

/// Platform touch phase
public enum PlatformTouchPhase {
    case began
    case moved
    case stationary
    case ended
    case cancelled
}

/// Platform mouse event type
public enum PlatformMouseEventType {
    case down
    case up
    case moved
    case dragged
    case entered
    case exited
    case rightClick
    case hover
}

/// Toolbar item
public struct ToolbarItem: Identifiable {
    public let id: String
    public let title: String
    public let icon: String
    public let action: ToolbarAction
    
    public enum ToolbarAction {
        case find
        case replace
        case showSymbols
        case format
        case custom(action: () -> Void)
    }
}

// Context menu types are now defined in ContextMenuAction.swift

// MARK: - ObserverStore Actor

/// Thread-safe storage for notification observers
@MainActor
private final class ObserverStore {
    private var observers: [NSObjectProtocol] = []
    
    func addObserver(_ observer: NSObjectProtocol) {
        observers.append(observer)
    }
    
    func removeAllObservers() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
    
    nonisolated func cleanup() {
        // Use MainActor to safely clean up observers
        Task { @MainActor in
            removeAllObservers()
        }
    }
    
    deinit {
        // Cannot access MainActor isolated properties in deinit with Swift 6
        // Cleanup happens automatically via the cleanup() task
        // NotificationCenter automatically removes observers when object is deallocated
    }
}
