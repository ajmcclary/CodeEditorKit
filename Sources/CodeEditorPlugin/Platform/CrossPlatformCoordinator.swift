import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
#if canImport(Combine)
import Combine
#endif

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
@available(macOS 10.15, iOS 13.0, *)
@MainActor
public final class CrossPlatformCoordinator: ObservableObject {
    // MARK: - Properties

    internal let logger = CrossPlatformLogger.logger()
    internal let capabilities: PlatformCapabilities

    /// Specialized coordinators for focused responsibilities
    public let inputCoordinator: InputCoordinator
    public let toolbarCoordinator: ToolbarCoordinator
    public let contextMenuCoordinator: ContextMenuCoordinator

    /// Platform-specific adjustments
    @Published internal var platformAdjustments = PlatformAdjustments()

    /// Thread-safe observer storage
    private let observerStore = ObserverStore()

    /// Weak reference to associated text view for toolbar actions
    internal weak var associatedTextView: CodeEditorView?

    // MARK: - Initialization

    /// Creates a new instance with specified dependencies
    /// - Parameters:
    ///   - capabilities: Platform capabilities provider (defaults to dependency factory)
    ///   - inputCoordinator: Input handling coordinator (defaults to new instance)
    ///   - toolbarCoordinator: Toolbar management coordinator (defaults to new instance)
    ///   - contextMenuCoordinator: Context menu coordinator (defaults to new instance)
    public init(
        capabilities: PlatformCapabilities? = nil,
        inputCoordinator: InputCoordinator? = nil,
        toolbarCoordinator: ToolbarCoordinator? = nil,
        contextMenuCoordinator: ContextMenuCoordinator? = nil
    ) {
        self.capabilities = capabilities ?? CodeEditorDependencies.makePlatformCapabilities()
        self.inputCoordinator = inputCoordinator ?? InputCoordinator()
        self.toolbarCoordinator = toolbarCoordinator ?? ToolbarCoordinator()
        self.contextMenuCoordinator = contextMenuCoordinator ?? ContextMenuCoordinator()

        adjustFeaturesForPlatform()
        setupPlatformSpecificObservers()
    }

    private convenience init() {
        let sharedCapabilities = CodeEditorDependencies.makePlatformCapabilities()
        self.init(
            capabilities: sharedCapabilities,
            inputCoordinator: InputCoordinator(capabilities: sharedCapabilities),
            toolbarCoordinator: ToolbarCoordinator(capabilities: sharedCapabilities),
            contextMenuCoordinator: ContextMenuCoordinator(capabilities: sharedCapabilities)
        )
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
        capabilities.recommendedConfiguration()
    }

    /// Apply platform-specific optimizations to a text view
    public func optimizeTextView(_ textView: CodeEditorView) {
        #if canImport(AppKit)
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
        // Skip this for Mac Catalyst to keep default values
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad gets platform-optimized adjustments
            platformAdjustments = PlatformAdjustments.forCurrentDevice()
        }
        #endif
    }

    private func setupPlatformSpecificObservers() {
        // Remove any existing observers first
        removeObservers()

        #if canImport(AppKit)
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

    #if canImport(UIKit)
    @objc func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    #endif

    // Context menu actions are now handled by ContextMenuCoordinator

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

    // MARK: - Shared Context Menu Actions

    #if canImport(AppKit)
    @objc func handleSharedMenuAction(_ menuItem: NSMenuItem) {
        if let action = menuItem.representedObject as? () -> Void {
            action()
        }
    }
    #endif

    // MARK: - Shared Editing Actions

    /// Toggle comment for selected lines in the text view
    /// - Parameter textView: The text view to operate on
    internal func toggleComment(in textView: CodeEditorView) {
        guard let text = textView.text else { return }
        let language = textView.language

        let selectedRange = textView.selectedRange

        // Get the comment syntax for the current language
        let commentPrefix = getCommentPrefix(for: language)

        // Convert to String.Index for line boundary calculations
        guard let startIndex = text.index(text.startIndex, offsetBy: selectedRange.location, limitedBy: text.endIndex) else { return }

        // Find line boundaries for the selection
        let lineRange = text.lineRange(for: startIndex..<startIndex)

        // Extract the line text
        let lineText = String(text[lineRange])
        let trimmedLine = lineText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedLine.hasPrefix(commentPrefix) {
            // Remove comment
            let uncommentedLine = lineText.replacingOccurrences(of: commentPrefix + " ", with: "")
                .replacingOccurrences(of: commentPrefix, with: "")

            // Build new text
            let beforeLine = String(text[..<lineRange.lowerBound])
            let afterLine = String(text[lineRange.upperBound...])
            let newText = beforeLine + uncommentedLine + afterLine
            textView.text = newText

            // Adjust selection
            let adjustment = lineText.count - uncommentedLine.count
            textView.selectedRange = NSRange(location: selectedRange.location - adjustment, length: selectedRange.length)
        } else {
            // Add comment
            let leadingWhitespace = lineText.prefix { $0.isWhitespace }
            let commentedLine = leadingWhitespace + commentPrefix + " " + lineText.dropFirst(leadingWhitespace.count)

            // Build new text
            let beforeLine = String(text[..<lineRange.lowerBound])
            let afterLine = String(text[lineRange.upperBound...])
            let newText = beforeLine + commentedLine + afterLine
            textView.text = newText

            // Adjust selection
            let adjustment = commentedLine.count - lineText.count
            textView.selectedRange = NSRange(location: selectedRange.location + adjustment, length: selectedRange.length)
        }
    }

    /// Get the comment prefix for a language
    /// - Parameter language: The language to get comment prefix for
    /// - Returns: The comment prefix string
    internal func getCommentPrefix(for language: Language) -> String {
        switch language {
        case .swift, .javascript, .typescript, .c, .cpp, .go, .rust, .java, .csharp, .kotlin, .dart:
            return "//"

        case .python, .ruby, .shell, .dockerfile, .toml:
            return "#"

        case .html, .xml:
            return "<!--"

        case .css:
            return "/*"

        case .sql:
            return "--"

        case .php:
            return "//"

        case .lua:
            return "--"

        case .yaml:
            return "#"

        case .markdown, .json, .plainText:
            return "//" // Default fallback
        }
    }
}

// MARK: - Supporting Types
// All supporting types have been moved to:
// - PlatformInputTypes.swift for input-related types
// - PlatformAdjustments.swift for platform adjustments
// - ObserverStore.swift for the observer management
