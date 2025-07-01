import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif
import os.log

/// Coordinator for ensuring cross-platform feature parity and smooth operation
@MainActor
public class CrossPlatformCoordinator: ObservableObject {
    // MARK: - Singleton
    
    public static let shared = CrossPlatformCoordinator()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "CodeEditorPlugin", category: "CrossPlatformCoordinator")
    private let capabilities = PlatformCapabilities.shared
    
    /// Platform-specific adjustments
    @Published public private(set) var platformAdjustments = PlatformAdjustments()
    
    /// Observer tokens for proper cleanup
    private nonisolated(unsafe) var notificationObservers: [Any] = []
    
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
        // Remove all notification observers
        removeObservers()
        
        // Remove legacy selector-based observers if any
        NotificationCenter.default.removeObserver(self)
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
    public func createToolbarItems() -> [ToolbarItem] {
        var items: [ToolbarItem] = []
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
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
        #else
        // Simplified toolbar on iOS
        items.append(ToolbarItem(
            id: "find",
            title: "Find",
            icon: "magnifyingglass",
            action: .find
        ))
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            items.append(ToolbarItem(
                id: "symbol",
                title: "Symbols",
                icon: "list.bullet.indent",
                action: .showSymbols
            ))
        }
        #endif
        
        return items
    }
    
    /// Handle platform-specific input events
    public func handlePlatformInput(_ event: PlatformInputEvent, in textView: CodeEditorView) -> Bool {
        switch event {
        case let .keyDown(key, modifiers):
            return handleKeyInput(key: key, modifiers: modifiers, in: textView)
            
        case let .touch(touches, phase):
            return handleTouchInput(touches: touches, phase: phase, in: textView)
            
        case let .mouse(location, type):
            return handleMouseInput(location: location, type: type, in: textView)
            
        case let .pencil(location, pressure, azimuth):
            return handlePencilInput(location: location, pressure: pressure, azimuth: azimuth, in: textView)
        }
    }
    
    /// Create cross-platform context menu using modern action-based API
    public func createContextMenu(for range: NSRange, in textView: CodeEditorView) -> PlatformContextMenu {
        var builder = ContextMenuBuilder()
        
        // Common editing actions - now using abstracted methods
        builder.addAction(ContextMenuAction(
            title: "Cut",
            keyEquivalent: "x",
            isEnabled: textView.canCut
        ) { @MainActor [weak textView] in
            textView?.performCut()
        })
        
        builder.addAction(ContextMenuAction(
            title: "Copy",
            keyEquivalent: "c",
            isEnabled: textView.canCopy
        ) { @MainActor [weak textView] in
            textView?.performCopy()
        })
        
        builder.addAction(ContextMenuAction(
            title: "Paste",
            keyEquivalent: "v",
            isEnabled: textView.canPaste
        ) { @MainActor [weak textView] in
            textView?.performPaste()
        })
        
        builder.addSeparator()
        
        // Code navigation actions
        if capabilities.isFeatureAvailable(.goToDefinition) {
            builder.addAction(ContextMenuAction(
                title: "Go to Definition",
                keyEquivalent: nil,
                isEnabled: true
            ) { @MainActor [weak self, weak textView] in
                self?.performGoToDefinition(at: range, in: textView)
            })
        }
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        builder.addAction(ContextMenuAction(
            title: "Find References",
            keyEquivalent: nil,
            isEnabled: true
        ) { @MainActor [weak self, weak textView] in
            self?.performFindReferences(at: range, in: textView)
        })
        
        builder.addSeparator()
        
        // Refactoring submenu
        builder.addAction(ContextMenuAction(
            title: "Rename...",
            keyEquivalent: nil,
            isEnabled: true
        ) { @MainActor [weak self, weak textView] in
            self?.performRename(at: range, in: textView)
        })
        
        builder.addAction(ContextMenuAction(
            title: "Extract Method...",
            keyEquivalent: nil,
            isEnabled: range.length > 0
        ) { @MainActor [weak self, weak textView] in
            self?.performExtractMethod(at: range, in: textView)
        })
        
        builder.addAction(ContextMenuAction(
            title: "Extract Variable...",
            keyEquivalent: nil,
            isEnabled: range.length > 0
        ) { @MainActor [weak self, weak textView] in
            self?.performExtractVariable(at: range, in: textView)
        })
        #endif
        
        return builder.build()
    }
    
    // MARK: - Private Methods
    
    private func adjustFeaturesForPlatform() {
        // Platform-specific adjustments are now handled by PlatformCapabilities
        // This method is kept for backward compatibility but can be removed in the future
        
        #if canImport(UIKit)
        // Update platform adjustments based on runtime checks
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad gets larger touch targets
            platformAdjustments.minimumTouchTargetSize = 44.0
        }
        
        // Check for external keyboard to adjust UI
        if isExternalKeyboardConnected() {
            // Could adjust UI for keyboard usage
        }
        
        // Check for mouse/trackpad to adjust hover behaviors
        if isPointingDeviceConnected() {
            // Could enable hover effects
        }
        #endif
    }
    
    private func setupPlatformSpecificObservers() {
        #if canImport(UIKit)
        // Remove any existing observers first
        removeObservers()
        
        // Observe keyboard connection changes
        let keyboardObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardDidShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Hop to the main actor to safely call main actor-isolated method
            Task { @MainActor in
                self?.keyboardDidConnect()
            }
        }
        notificationObservers.append(keyboardObserver)
        
        // Observe device orientation changes
        let orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.orientationDidChange()
            }
        }
        notificationObservers.append(orientationObserver)
        #endif
    }
    
    private nonisolated func removeObservers() {
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        notificationObservers.removeAll()
    }
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    private func optimizeForMacOS(_ textView: CodeEditorView) {
        // Enable platform-specific features
        // Note: CodeEditorView doesn't currently support multiple selection
        
        // Set up rulers and guides
        if let scrollView = textView.enclosingScrollView {
            scrollView.rulersVisible = false // Can be toggled by user
        }
    }
    #else
    private func optimizeForIOS(_ textView: CodeEditorView) {
        // Configure for touch
        textView.isSelectable = true
        textView.isEditable = true
        
        // Adjust content insets for safe area
        if let window = textView.window {
            let safeArea = window.safeAreaInsets
            let insets = EdgeInsets(
                top: safeArea.top + 8,
                left: 0,
                bottom: safeArea.bottom + 8,
                right: 0
            )
            textView.setUnifiedTextContainerInsets(insets)
        }
        
        // Configure keyboard
        textView.keyboardType = .default
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        
        // Add input accessory view for iPad
        if UIDevice.current.userInterfaceIdiom == .pad {
            textView.inputAccessoryView = createInputAccessoryView()
        }
    }
    
    private func createInputAccessoryView() -> UIView {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        let items = [
            UIBarButtonItem(image: UIImage(systemName: "arrow.uturn.backward"), style: .plain, target: nil, action: #selector(undo)),
            UIBarButtonItem(image: UIImage(systemName: "arrow.uturn.forward"), style: .plain, target: nil, action: #selector(redo)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(image: UIImage(systemName: "magnifyingglass"), style: .plain, target: nil, action: #selector(find)),
            UIBarButtonItem(image: UIImage(systemName: "keyboard.chevron.compact.down"), style: .plain, target: nil, action: #selector(dismissKeyboard))
        ]
        
        toolbar.items = items
        return toolbar
    }
    #endif
    
    private func handleKeyInput(key: String, modifiers: PlatformModifierFlags, in textView: CodeEditorView) -> Bool {
        // Platform-specific key handling
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // Full keyboard shortcut support
        if modifiers.contains(.command) {
            switch key {
            case "d": selectNextOccurrence(in: textView); return true
            case "l": selectLine(in: textView); return true
            case "/": toggleComment(in: textView); return true
            default: break
            }
        }
        #else
        // Limited keyboard support on iOS
        if isExternalKeyboardConnected() && modifiers.contains(.command) {
            switch key {
            case "f": showFind(in: textView); return true
            case "z": textView.undoManager?.undo(); return true
            default: break
            }
        }
        #endif
        
        return false
    }
    
    private func handleTouchInput(touches: Set<AnyHashable>, phase: PlatformTouchPhase, in textView: CodeEditorView) -> Bool {
        #if canImport(UIKit)
        // Handle multi-touch gestures
        if touches.count == 2 {
            // Two-finger tap for context menu
            if phase == .ended {
                showContextMenu(in: textView)
                return true
            }
        }
        #endif
        return false
    }
    
    private func handleMouseInput(location: CGPoint, type: PlatformMouseEventType, in textView: CodeEditorView) -> Bool {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // Handle mouse events
        switch type {
        case .rightClick:
            showContextMenu(at: location, in: textView)
            return true

        case .hover:
            // Show hover information
            return false

        default:
            return false
        }
        #else
        // Limited mouse support on iOS
        if isPointingDeviceConnected() {
            switch type {
            case .rightClick:
                showContextMenu(at: location, in: textView)
                return true

            default:
                return false
            }
        }
        return false
        #endif
    }
    
    private func handlePencilInput(location: CGPoint, pressure: CGFloat, azimuth _: CGFloat, in textView: CodeEditorView) -> Bool {
        #if canImport(UIKit)
        // Handle Apple Pencil input
        if pressure > 0.5 {
            // Heavy pressure for selection
            startSelection(at: location, in: textView)
            return true
        }
        #endif
        return false
    }
    
    // MARK: - Helper Methods
    
    #if canImport(UIKit)
    private func isExternalKeyboardConnected() -> Bool {
        // Check if external keyboard is connected
        // This is a simplified check
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    private func isPointingDeviceConnected() -> Bool {
        // Check if mouse/trackpad is connected
        if #available(iOS 13.4, *) {
            return UIDevice.current.userInterfaceIdiom == .pad
        }
        return false
    }
    
    private func keyboardDidConnect() {
        adjustFeaturesForPlatform()
    }
    
    private func orientationDidChange() {
        #if canImport(UIKit)
        // Adjust UI for new orientation
        let orientation = UIDevice.current.orientation
        
        // Update platform adjustments based on orientation
        if orientation.isLandscape {
            // In landscape, we can use slightly smaller touch targets
            platformAdjustments.minimumTouchTargetSize = 40
        } else {
            // Portrait uses standard iOS touch target size
            platformAdjustments.minimumTouchTargetSize = 44
        }
        
        // Notify observers of the change
        objectWillChange.send()
        #endif
    }
    
    @objc private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    #endif
    
    @objc private func undo() {
        // Undo implementation
    }
    
    @objc private func redo() {
        // Redo implementation
    }
    
    @objc private func find() {
        // Find implementation
    }
    
    private func performGoToDefinition(at range: NSRange, in _: CodeEditorView?) {
        // Go to definition implementation
        logger.info("Go to definition at range: \(range)")
    }
    
    private func performFindReferences(at range: NSRange, in _: CodeEditorView?) {
        // Find references implementation
        logger.info("Find references at range: \(range)")
    }
    
    private func performRename(at range: NSRange, in _: CodeEditorView?) {
        // Rename implementation
        logger.info("Rename at range: \(range)")
    }
    
    private func performExtractMethod(at range: NSRange, in _: CodeEditorView?) {
        // Extract method implementation
        logger.info("Extract method at range: \(range)")
    }
    
    private func performExtractVariable(at range: NSRange, in _: CodeEditorView?) {
        // Extract variable implementation
        logger.info("Extract variable at range: \(range)")
    }
    
    private func selectNextOccurrence(in _: CodeEditorView) {
        // Select next occurrence implementation
    }
    
    private func selectLine(in _: CodeEditorView) {
        // Select line implementation
    }
    
    private func toggleComment(in _: CodeEditorView) {
        // Toggle comment implementation
    }
    
    private func showFind(in _: CodeEditorView) {
        // Show find UI
    }
    
    private func showContextMenu(in textView: CodeEditorView) {
        showContextMenu(at: CGPoint.zero, in: textView)
    }
    
    private func showContextMenu(at _: CGPoint, in _: CodeEditorView) {
        // Show context menu at location
    }
    
    private func startSelection(at _: CGPoint, in _: CodeEditorView) {
        // Start selection at location
    }
    
    // Context menu helper methods
    private func configureInputHandling(for textView: CodeEditorView) {
        #if canImport(UIKit)
        // Add gesture recognizers for iOS
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        textView.addGestureRecognizer(longPressGesture)
        #endif
    }
    
    #if canImport(UIKit)
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let textView = gesture.view as? CodeEditorView else { return }
        
        let location = gesture.location(in: textView)
        showContextMenu(at: location, in: textView)
    }
    #endif
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
