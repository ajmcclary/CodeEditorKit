import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
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
    
    /// Feature availability matrix
    @Published public private(set) var featureAvailability = FeatureAvailabilityMatrix()
    
    /// Platform-specific adjustments
    @Published public private(set) var platformAdjustments = PlatformAdjustments()
    
    // MARK: - Types
    
    /// Matrix of feature availability across platforms
    public struct FeatureAvailabilityMatrix {
        // Core features
        public var syntaxHighlighting = FeatureStatus(macOS: .full, iOS: .full)
        public var codeCompletion = FeatureStatus(macOS: .full, iOS: .full)
        public var lineNumbers = FeatureStatus(macOS: .full, iOS: .full)
        public var codeFollowing = FeatureStatus(macOS: .full, iOS: .partial)
        public var minimap = FeatureStatus(macOS: .full, iOS: .unavailable)
        
        // Editing features
        public var multiCursor = FeatureStatus(macOS: .full, iOS: .partial)
        public var smartBrackets = FeatureStatus(macOS: .full, iOS: .full)
        public var autoIndent = FeatureStatus(macOS: .full, iOS: .full)
        public var findReplace = FeatureStatus(macOS: .full, iOS: .partial)
        public var columnSelection = FeatureStatus(macOS: .full, iOS: .unavailable)
        
        // Navigation features
        public var symbolNavigation = FeatureStatus(macOS: .full, iOS: .partial)
        public var breadcrumbs = FeatureStatus(macOS: .full, iOS: .partial)
        public var goToDefinition = FeatureStatus(macOS: .full, iOS: .partial)
        public var quickOpen = FeatureStatus(macOS: .full, iOS: .partial)
        
        // Performance features
        public var hardwareAcceleration = FeatureStatus(macOS: .full, iOS: .full)
        public var virtualScrolling = FeatureStatus(macOS: .full, iOS: .full)
        public var incrementalParsing = FeatureStatus(macOS: .full, iOS: .full)
        public var backgroundProcessing = FeatureStatus(macOS: .full, iOS: .full)
        
        // Integration features
        public var lspSupport = FeatureStatus(macOS: .full, iOS: .partial)
        public var pluginSystem = FeatureStatus(macOS: .full, iOS: .partial)
        public var externalTools = FeatureStatus(macOS: .full, iOS: .unavailable)
        public var fileWatching = FeatureStatus(macOS: .full, iOS: .partial)
        
        // UI features
        public var splitView = FeatureStatus(macOS: .full, iOS: .partial)
        public var tabs = FeatureStatus(macOS: .full, iOS: .partial)
        public var sidebars = FeatureStatus(macOS: .full, iOS: .partial)
        public var floatingPanels = FeatureStatus(macOS: .full, iOS: .unavailable)
        public var contextMenus = FeatureStatus(macOS: .full, iOS: .full)
        public var toolbars = FeatureStatus(macOS: .full, iOS: .partial)
        
        // Input features
        public var keyboardShortcuts = FeatureStatus(macOS: .full, iOS: .partial)
        public var mouseSupport = FeatureStatus(macOS: .full, iOS: .partial)
        public var touchSupport = FeatureStatus(macOS: .partial, iOS: .full)
        public var gestures = FeatureStatus(macOS: .partial, iOS: .full)
        public var pencilSupport = FeatureStatus(macOS: .unavailable, iOS: .full)
    }
    
    /// Status of a feature on different platforms
    public struct FeatureStatus {
        public enum Availability {
            case full
            case partial
            case unavailable
            
            public var icon: String {
                switch self {
                case .full: return "checkmark.circle.fill"
                case .partial: return "exclamationmark.circle"
                case .unavailable: return "xmark.circle"
                }
            }
            
            public var color: Color {
                switch self {
                case .full: return .green
                case .partial: return .orange
                case .unavailable: return .red
                }
            }
        }
        
        public let macOS: Availability
        public let iOS: Availability
        
        public var currentPlatform: Availability {
            #if os(macOS)
            return macOS
            #else
            return iOS
            #endif
        }
        
        public var isAvailable: Bool {
            currentPlatform != .unavailable
        }
        
        public var isFullyAvailable: Bool {
            currentPlatform == .full
        }
    }
    
    /// Platform-specific adjustments
    public struct PlatformAdjustments {
        // Font adjustments
        public var defaultFontSize: CGFloat = {
            #if os(macOS)
            return 12.0
            #else
            return 14.0 // Larger for touch
            #endif
        }()
        
        // Spacing adjustments
        public var lineSpacing: CGFloat = {
            #if os(macOS)
            return 1.2
            #else
            return 1.4 // More spacing for touch
            #endif
        }()
        
        public var gutterWidth: CGFloat = {
            #if os(macOS)
            return 40.0
            #else
            return 50.0 // Wider for touch targets
            #endif
        }()
        
        // Touch adjustments
        public var minimumTouchTargetSize: CGFloat = {
            #if os(macOS)
            return 24.0
            #else
            return 44.0 // iOS HIG recommendation
            #endif
        }()
        
        // Performance adjustments
        public var maxFileSize: Int = {
            #if os(macOS)
            return 10_000_000 // 10MB
            #else
            return 5_000_000 // 5MB for iOS
            #endif
        }()
        
        public var maxHighlightingLength: Int = {
            #if os(macOS)
            return 1_000_000
            #else
            return 500_000 // Less for iOS
            #endif
        }()
        
        // UI adjustments
        public var showMinimap: Bool = {
            #if os(macOS)
            return true
            #else
            return false // Not supported on iOS
            #endif
        }()
        
        public var enableMultiCursor: Bool = {
            #if os(macOS)
            return true
            #else
            return UIDevice.current.userInterfaceIdiom == .pad
            #endif
        }()
    }
    
    // MARK: - Initialization
    
    private init() {
        adjustFeaturesForPlatform()
        setupPlatformSpecificObservers()
    }
    
    deinit {
        // Cleanup is handled automatically by ARC
    }
    
    // MARK: - Public Methods
    
    /// Check if a specific feature is available on the current platform
    public func isFeatureAvailable(_ keyPath: KeyPath<FeatureAvailabilityMatrix, FeatureStatus>) -> Bool {
        featureAvailability[keyPath: keyPath].isAvailable
    }
    
    /// Get recommended configuration for current platform
    public func recommendedConfiguration() -> EditorConfiguration {
        var config = EditorConfiguration()
        
        // Apply platform-specific defaults
        config.display.fontSize = platformAdjustments.defaultFontSize
        config.layout.lineSpacing = platformAdjustments.lineSpacing
        config.layout.gutterWidth = platformAdjustments.gutterWidth
        config.performance.maxSyntaxHighlightingLength = platformAdjustments.maxHighlightingLength
        
        // Disable unavailable features
        if !featureAvailability.minimap.isAvailable {
            // config.display.showMinimap = false
        }
        
        if !featureAvailability.multiCursor.isFullyAvailable {
            // Limit multi-cursor on iOS
        }
        
        #if os(iOS)
        // iOS-specific adjustments
        config.display.lineHeightMultiplier = 1.3 // More space for touch
        config.behavior.enableHapticFeedback = true
        config.behavior.showTouchIndicators = true
        #endif
        
        return config
    }
    
    /// Apply platform-specific optimizations to a text view
    public func optimizeTextView(_ textView: CodeEditorView) {
        #if os(macOS)
        optimizeForMacOS(textView)
        #else
        optimizeForIOS(textView)
        #endif
    }
    
    /// Create platform-appropriate toolbar items
    public func createToolbarItems() -> [ToolbarItem] {
        var items: [ToolbarItem] = []
        
        #if os(macOS)
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
    
    /// Create cross-platform context menu
    public func createContextMenu(for _: NSRange, in _: CodeEditorView) -> PlatformContextMenu {
        var items: [ContextMenuItem] = []
        
        // Common items
        items.append(ContextMenuItem(title: "Cut", action: #selector(NSText.cut(_:))))
        items.append(ContextMenuItem(title: "Copy", action: #selector(NSText.copy(_:))))
        items.append(ContextMenuItem(title: "Paste", action: #selector(NSText.paste(_:))))
        items.append(ContextMenuItem.separator())
        
        // Platform-specific items
        #if os(macOS)
        items.append(ContextMenuItem(title: "Go to Definition", action: #selector(goToDefinition)))
        items.append(ContextMenuItem(title: "Find References", action: #selector(findReferences)))
        items.append(ContextMenuItem.separator())
        items.append(ContextMenuItem(title: "Refactor", submenu: createRefactorMenu()))
        #else
        if featureAvailability.goToDefinition.isAvailable {
            items.append(ContextMenuItem(title: "Go to Definition", action: #selector(goToDefinition)))
        }
        #endif
        
        return PlatformContextMenu(items: items)
    }
    
    // MARK: - Private Methods
    
    private func adjustFeaturesForPlatform() {
        // Adjust feature availability based on runtime checks
        
        #if os(iOS)
        // Check iPad-specific features
        if UIDevice.current.userInterfaceIdiom == .pad {
            featureAvailability.splitView = FeatureStatus(macOS: .full, iOS: .full)
            featureAvailability.multiCursor = FeatureStatus(macOS: .full, iOS: .full)
            featureAvailability.keyboardShortcuts = FeatureStatus(macOS: .full, iOS: .full)
        }
        
        // Check for external keyboard
        if isExternalKeyboardConnected() {
            featureAvailability.keyboardShortcuts = FeatureStatus(macOS: .full, iOS: .full)
        }
        
        // Check for mouse/trackpad
        if isPointingDeviceConnected() {
            featureAvailability.mouseSupport = FeatureStatus(macOS: .full, iOS: .full)
        }
        #endif
    }
    
    private func setupPlatformSpecificObservers() {
        #if os(iOS)
        // Observe keyboard connection changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidConnect),
            name: UIResponder.keyboardDidShowNotification,
            object: nil
        )
        
        // Observe device orientation changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        #endif
    }
    
    #if os(macOS)
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
            textView.textContainerInset = UIEdgeInsets(
                top: safeArea.top + 8,
                left: 0,
                bottom: safeArea.bottom + 8,
                right: 0
            )
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
        #if os(macOS)
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
        #if os(iOS)
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
        #if os(macOS)
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
        #endif
        return false
    }
    
    private func handlePencilInput(location: CGPoint, pressure: CGFloat, azimuth _: CGFloat, in textView: CodeEditorView) -> Bool {
        #if os(iOS)
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
    
    #if os(iOS)
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
    
    @objc private func keyboardDidConnect() {
        adjustFeaturesForPlatform()
    }
    
    @objc private func orientationDidChange() {
        // Adjust UI for new orientation
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
    
    @objc private func goToDefinition() {
        // Go to definition implementation
    }
    
    @objc private func findReferences() {
        // Find references implementation
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
    
    #if os(macOS)
    private func createRefactorMenu() -> NSMenu {
        let menu = NSMenu(title: "Refactor")
        menu.addItem(NSMenuItem(title: "Rename", action: #selector(rename), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Extract Method", action: #selector(extractMethod), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Extract Variable", action: #selector(extractVariable), keyEquivalent: ""))
        return menu
    }
    
    @objc private func rename() {}
    @objc private func extractMethod() {}
    @objc private func extractVariable() {}
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

/// Context menu item
public struct ContextMenuItem {
    public let title: String
    public let action: Selector?
    public let submenu: PlatformMenu?
    public let isSeparator: Bool
    
    public init(title: String, action: Selector? = nil, submenu: PlatformMenu? = nil) {
        self.title = title
        self.action = action
        self.submenu = submenu
        self.isSeparator = false
    }
    
    private init(separator: Bool) {
        self.title = ""
        self.action = nil
        self.submenu = nil
        self.isSeparator = separator
    }
    
    public static func separator() -> Self {
        Self(separator: true)
    }
}

/// Platform context menu
public struct PlatformContextMenu {
    public let items: [ContextMenuItem]
}

/// Platform menu (for submenus)
public protocol PlatformMenu {
    var title: String { get }
    var items: [ContextMenuItem] { get }
}

#if os(macOS)
extension NSMenu: PlatformMenu {
    public var items: [ContextMenuItem] {
        // Convert NSMenuItems to ContextMenuItems
        []
    }
}
#endif
