import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

/// Coordinator responsible for creating and managing cross-platform context menus
///
/// `ContextMenuCoordinator` provides unified context menu management across different platforms,
/// ensuring appropriate menu items are available based on platform capabilities, context,
/// and user interface patterns.
///
/// ## Overview
///
/// This coordinator abstracts the differences between:
/// - macOS: Rich context menus with submenus and keyboard shortcuts
/// - iOS: Touch-optimized context menus with clear visual hierarchy
/// - Mac Catalyst: Hybrid menus supporting both mouse and touch interaction
///
/// ## Features
///
/// - **Context-Aware**: Menu items change based on selection and cursor position
/// - **Platform-Adaptive**: Automatically adjusts menu structure for platform
/// - **Capability-Aware**: Only shows items for supported features
/// - **Accessibility**: Ensures all menu items are properly accessible
/// - **Extensible**: Allows for custom menu item injection
///
/// ## Example Usage
///
/// ```swift
/// let coordinator = ContextMenuCoordinator.shared
/// 
/// // Create context menu for text selection
/// let menu = coordinator.createContextMenu(
///     for: selectedRange,
///     in: textView,
///     context: .textSelection
/// )
/// 
/// // Show context menu at specific location
/// coordinator.showContextMenu(menu, at: location, in: textView)
/// 
/// // Create custom menu for specific scenario
/// let customMenu = coordinator.createEditingMenu(canCut: true, canPaste: false)
/// ```
///
/// - SeeAlso: ``CrossPlatformCoordinator`` for overall coordination
/// - SeeAlso: ``PlatformCapabilities`` for feature detection
/// - SeeAlso: ``ContextMenuAction`` for menu action definitions
@MainActor
public final class ContextMenuCoordinator: ObservableObject {
    /// Shared instance for backward compatibility
    /// - Warning: This property is deprecated. Use dependency injection instead.
    @available(*, deprecated, message: "Use dependency injection instead of the singleton pattern")
    public static let shared = ContextMenuCoordinator()

    private let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "ContextMenuCoordinator")
    private let capabilities: PlatformCapabilities

    /// Context types for menu customization
    public enum MenuContext {
        case textSelection
        case emptyArea
        case lineNumber
        case annotation
        case searchResult
        case symbolReference
    }

    // MARK: - Initialization

    /// Creates a new ContextMenuCoordinator instance
    /// - Parameter capabilities: Platform capabilities provider (defaults to shared instance)
    public init(capabilities: PlatformCapabilities? = nil) {
        self.capabilities = capabilities ?? PlatformCapabilities.shared
        logger.debug("ContextMenuCoordinator initialized")
    }

    // MARK: - Public Methods

    /// Create cross-platform context menu using modern action-based API
    ///
    /// This method creates a context menu appropriate for the given context and platform,
    /// automatically including relevant actions based on capabilities and state.
    ///
    /// - Parameters:
    ///   - range: The text range associated with the menu
    ///   - textView: The target text view
    ///   - context: The context type for menu customization
    /// - Returns: Platform-appropriate context menu
    public func createContextMenu(
        for range: NSRange,
        in textView: CodeEditorView,
        context: MenuContext = .textSelection
    ) -> PlatformContextMenu {
        var builder = ContextMenuBuilder()

        switch context {
        case .textSelection:
            addTextSelectionActions(to: &builder, range: range, textView: textView)

        case .emptyArea:
            addEmptyAreaActions(to: &builder, textView: textView)

        case .lineNumber:
            addLineNumberActions(to: &builder, range: range, textView: textView)

        case .annotation:
            addAnnotationActions(to: &builder, range: range, textView: textView)

        case .searchResult:
            addSearchResultActions(to: &builder, range: range, textView: textView)

        case .symbolReference:
            addSymbolReferenceActions(to: &builder, range: range, textView: textView)
        }

        logger.debug("Created context menu for \(String(describing: context)) with \(builder.actionCount) actions")
        return builder.build()
    }

    /// Create basic editing context menu
    ///
    /// Returns a minimal context menu with essential editing operations.
    ///
    /// - Parameters:
    ///   - canCut: Whether cut operation is available
    ///   - canCopy: Whether copy operation is available
    ///   - canPaste: Whether paste operation is available
    /// - Returns: Basic editing context menu
    public func createEditingMenu(canCut: Bool, canCopy: Bool, canPaste: Bool) -> PlatformContextMenu {
        var builder = ContextMenuBuilder()

        if canCut {
            builder.addAction(createCutAction())
        }

        if canCopy {
            builder.addAction(createCopyAction())
        }

        if canPaste {
            builder.addAction(createPasteAction())
        }

        return builder.build()
    }

    /// Create code navigation context menu
    ///
    /// Returns a context menu focused on code navigation and exploration.
    ///
    /// - Parameters:
    ///   - range: The text range for navigation
    ///   - textView: The target text view
    /// - Returns: Code navigation context menu
    public func createNavigationMenu(for range: NSRange, in textView: CodeEditorView) -> PlatformContextMenu {
        var builder = ContextMenuBuilder()

        if capabilities.isFeatureAvailable(.goToDefinition) {
            builder.addAction(ContextMenuAction(
                title: "Go to Definition",
                keyEquivalent: "d",
                modifiers: [.command],
                isEnabled: true
            ) { @MainActor [weak self] in
                self?.performGoToDefinition(at: range, in: textView)
            })
        }

        if capabilities.isFeatureAvailable(.symbolNavigation) {
            builder.addAction(ContextMenuAction(
                title: "Find References",
                keyEquivalent: "r",
                modifiers: [.command, .shift],
                isEnabled: true
            ) { @MainActor [weak self] in
                self?.performFindReferences(at: range, in: textView)
            })
        }

        if capabilities.isFeatureAvailable(.symbolNavigation) {
            builder.addAction(ContextMenuAction(
                title: "Find in Workspace",
                keyEquivalent: "f",
                modifiers: [.command, .shift],
                isEnabled: true
            ) { @MainActor [weak self] in
                self?.performWorkspaceSearch(at: range, in: textView)
            })
        }

        return builder.build()
    }

    /// Create refactoring context menu
    ///
    /// Returns a context menu with code refactoring options.
    ///
    /// - Parameters:
    ///   - range: The text range for refactoring
    ///   - textView: The target text view
    /// - Returns: Refactoring context menu
    public func createRefactoringMenu(for range: NSRange, in textView: CodeEditorView) -> PlatformContextMenu {
        var builder = ContextMenuBuilder()

        // Only show refactoring on platforms that support it well
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if capabilities.currentPlatform == .macOS { // Refactoring only on macOS
            builder.addAction(ContextMenuAction(
                title: "Rename Symbol",
                keyEquivalent: "r",
                modifiers: [.command],
                isEnabled: true
            ) { @MainActor [weak self] in
                self?.performRename(at: range, in: textView)
            })

            if range.length > 0 {
                builder.addSeparator()

                builder.addAction(ContextMenuAction(
                    title: "Extract Method",
                    keyEquivalent: nil,
                    isEnabled: true
                ) { @MainActor [weak self] in
                    self?.performExtractMethod(at: range, in: textView)
                })

                builder.addAction(ContextMenuAction(
                    title: "Extract Variable",
                    keyEquivalent: nil,
                    isEnabled: true
                ) { @MainActor [weak self] in
                    self?.performExtractVariable(at: range, in: textView)
                })

                builder.addAction(ContextMenuAction(
                    title: "Inline Variable",
                    keyEquivalent: nil,
                    isEnabled: true
                ) { @MainActor [weak self] in
                    self?.performInlineVariable(at: range, in: textView)
                })
            }
        }
        #endif

        return builder.build()
    }

    /// Show context menu at specified location
    ///
    /// - Parameters:
    ///   - menu: The context menu to show
    ///   - location: The location to show the menu
    ///   - textView: The target text view
    public func showContextMenu(_ menu: PlatformContextMenu, at location: CGPoint, in textView: CodeEditorView) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        showMacOSContextMenu(menu, at: location, in: textView)
        #else
        showIOSContextMenu(menu, at: location, in: textView)
        #endif
    }

    // MARK: - Menu Building Helpers

    private func addTextSelectionActions(to builder: inout ContextMenuBuilder, range: NSRange, textView: CodeEditorView) {
        // Basic editing actions
        if textView.canCut {
            builder.addAction(createCutAction(for: textView))
        }

        if textView.canCopy {
            builder.addAction(createCopyAction(for: textView))
        }

        if textView.canPaste {
            builder.addAction(createPasteAction(for: textView))
        }

        builder.addSeparator()

        // Selection actions
        builder.addAction(ContextMenuAction(
            title: "Select All",
            keyEquivalent: "a",
            modifiers: [.command],
            isEnabled: true
        ) { @MainActor [weak textView] in
            textView?.selectAll(nil)
        })

        if range.length > 0 {
            // Code navigation actions for selected text
            if capabilities.isFeatureAvailable(.goToDefinition) {
                builder.addSeparator()
                builder.addAction(ContextMenuAction(
                    title: "Go to Definition",
                    keyEquivalent: nil,
                    isEnabled: true
                ) { @MainActor [weak self] in
                    self?.performGoToDefinition(at: range, in: textView)
                })
            }

            // Platform-specific advanced actions
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            addMacOSAdvancedActions(to: &builder, range: range, textView: textView)
            #endif
        }
    }

    private func addEmptyAreaActions(to builder: inout ContextMenuBuilder, textView: CodeEditorView) {
        // Paste action for empty area
        if textView.canPaste {
            builder.addAction(createPasteAction(for: textView))
        }

        builder.addAction(ContextMenuAction(
            title: "Select All",
            keyEquivalent: "a",
            modifiers: [.command],
            isEnabled: true
        ) { @MainActor [weak textView] in
            textView?.selectAll(nil)
        })

        // Platform-specific empty area actions
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        builder.addSeparator()

        builder.addAction(ContextMenuAction(
            title: "Show Rulers",
            keyEquivalent: nil,
            isEnabled: true
        ) { @MainActor [weak textView] in
            textView?.toggleRuler(nil)
        })
        #endif
    }

    private func addLineNumberActions(to builder: inout ContextMenuBuilder, range: NSRange, textView: CodeEditorView) {
        builder.addAction(ContextMenuAction(
            title: "Toggle Breakpoint",
            keyEquivalent: nil,
            isEnabled: capabilities.currentPlatform == .macOS // Debugging only on macOS
        ) { @MainActor [weak self] in
            self?.performToggleBreakpoint(at: range, in: textView)
        })

        builder.addAction(ContextMenuAction(
            title: "Add Bookmark",
            keyEquivalent: nil,
            isEnabled: capabilities.currentPlatform == .macOS // Bookmarks only on macOS
        ) { @MainActor [weak self] in
            self?.performAddBookmark(at: range, in: textView)
        })

        builder.addSeparator()

        builder.addAction(ContextMenuAction(
            title: "Go to Line...",
            keyEquivalent: "l",
            modifiers: [.command],
            isEnabled: true
        ) { @MainActor [weak self] in
            self?.performGoToLine(in: textView)
        })
    }

    private func addAnnotationActions(to builder: inout ContextMenuBuilder, range: NSRange, textView: CodeEditorView) {
        builder.addAction(ContextMenuAction(
            title: "Show Details",
            keyEquivalent: nil,
            isEnabled: true
        ) { @MainActor [weak self] in
            self?.performShowAnnotationDetails(at: range, in: textView)
        })

        builder.addAction(ContextMenuAction(
            title: "Quick Fix",
            keyEquivalent: nil,
            isEnabled: true // Quick fix always available
        ) { @MainActor [weak self] in
            self?.performQuickFix(at: range, in: textView)
        })

        builder.addSeparator()

        builder.addAction(ContextMenuAction(
            title: "Ignore Warning",
            keyEquivalent: nil,
            isEnabled: true
        ) { @MainActor [weak self] in
            self?.performIgnoreWarning(at: range, in: textView)
        })
    }

    private func addSearchResultActions(to builder: inout ContextMenuBuilder, range: NSRange, textView: CodeEditorView) {
        builder.addAction(ContextMenuAction(
            title: "Replace",
            keyEquivalent: nil,
            isEnabled: capabilities.isFeatureAvailable(.findReplace)
        ) { @MainActor [weak self] in
            self?.performReplace(at: range, in: textView)
        })

        builder.addAction(ContextMenuAction(
            title: "Replace All",
            keyEquivalent: nil,
            isEnabled: capabilities.isFeatureAvailable(.findReplace)
        ) { @MainActor [weak self] in
            self?.performReplaceAll(in: textView)
        })
    }

    private func addSymbolReferenceActions(to builder: inout ContextMenuBuilder, range: NSRange, textView: CodeEditorView) {
        builder.addAction(ContextMenuAction(
            title: "Go to Definition",
            keyEquivalent: nil,
            isEnabled: capabilities.isFeatureAvailable(.goToDefinition)
        ) { @MainActor [weak self] in
            self?.performGoToDefinition(at: range, in: textView)
        })

        builder.addAction(ContextMenuAction(
            title: "Find All References",
            keyEquivalent: nil,
            isEnabled: capabilities.isFeatureAvailable(.symbolNavigation)
        ) { @MainActor [weak self] in
            self?.performFindReferences(at: range, in: textView)
        })

        builder.addAction(ContextMenuAction(
            title: "Rename Symbol",
            keyEquivalent: nil,
            isEnabled: capabilities.currentPlatform == .macOS // Refactoring only on macOS
        ) { @MainActor [weak self] in
            self?.performRename(at: range, in: textView)
        })
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    private func addMacOSAdvancedActions(to builder: inout ContextMenuBuilder, range: NSRange, textView: CodeEditorView) {
        if capabilities.currentPlatform == .macOS { // Refactoring only on macOS
            builder.addSeparator()

            // Refactoring submenu
            var refactoringBuilder = ContextMenuBuilder()

            refactoringBuilder.addAction(ContextMenuAction(
                title: "Rename...",
                keyEquivalent: nil,
                isEnabled: true
            ) { @MainActor [weak self] in
                self?.performRename(at: range, in: textView)
            })

            if range.length > 0 {
                refactoringBuilder.addAction(ContextMenuAction(
                    title: "Extract Method...",
                    keyEquivalent: nil,
                    isEnabled: true
                ) { @MainActor [weak self] in
                    self?.performExtractMethod(at: range, in: textView)
                })

                refactoringBuilder.addAction(ContextMenuAction(
                    title: "Extract Variable...",
                    keyEquivalent: nil,
                    isEnabled: true
                ) { @MainActor [weak self] in
                    self?.performExtractVariable(at: range, in: textView)
                })
            }

            builder.addSubmenu(title: "Refactor", actions: refactoringBuilder.actions)
        }
    }
    #endif

    // MARK: - Action Factories

    private func createCutAction(for textView: CodeEditorView? = nil) -> ContextMenuAction {
        ContextMenuAction(
            title: "Cut",
            keyEquivalent: "x",
            modifiers: [.command],
            isEnabled: textView?.canCut ?? true
        ) { @MainActor [weak textView] in
            textView?.cut(nil)
        }
    }

    private func createCopyAction(for textView: CodeEditorView? = nil) -> ContextMenuAction {
        ContextMenuAction(
            title: "Copy",
            keyEquivalent: "c",
            modifiers: [.command],
            isEnabled: textView?.canCopy ?? true
        ) { @MainActor [weak textView] in
            textView?.copy(nil)
        }
    }

    private func createPasteAction(for textView: CodeEditorView? = nil) -> ContextMenuAction {
        ContextMenuAction(
            title: "Paste",
            keyEquivalent: "v",
            modifiers: [.command],
            isEnabled: textView?.canPaste ?? true
        ) { @MainActor [weak textView] in
            textView?.paste(nil)
        }
    }

    // MARK: - Platform-Specific Display

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    private func showMacOSContextMenu(_ menu: PlatformContextMenu, at location: CGPoint, in textView: CodeEditorView) {
        // Show the NSMenu directly
        menu.popUp(positioning: nil, at: location, in: textView)
    }
    #endif

    #if canImport(UIKit)
    private func showIOSContextMenu(_: PlatformContextMenu, at location: CGPoint, in _: CodeEditorView) {
        // Convert to UIMenu and show via UIMenuController or context menu interaction
        // Implementation would depend on specific UI requirements
        logger.debug("Showing iOS context menu at (\(location.x), \(location.y))")
    }
    #endif

    // MARK: - Action Implementations

    private func performGoToDefinition(at range: NSRange, in _: CodeEditorView?) {
        logger.info("Go to definition at range: \(range)")
        // Implementation would navigate to symbol definition
    }

    private func performFindReferences(at range: NSRange, in _: CodeEditorView?) {
        logger.info("Find references at range: \(range)")
        // Implementation would show references panel
    }

    private func performWorkspaceSearch(at range: NSRange, in _: CodeEditorView?) {
        logger.info("Workspace search at range: \(range)")
        // Implementation would open workspace search
    }

    private func performRename(at range: NSRange, in _: CodeEditorView?) {
        logger.info("Rename at range: \(range)")
        // Implementation would start rename operation
    }

    private func performExtractMethod(at range: NSRange, in _: CodeEditorView?) {
        logger.info("Extract method at range: \(range)")
        // Implementation would extract selected code to method
    }

    private func performExtractVariable(at range: NSRange, in _: CodeEditorView?) {
        logger.info("Extract variable at range: \(range)")
        // Implementation would extract expression to variable
    }

    private func performInlineVariable(at range: NSRange, in _: CodeEditorView?) {
        logger.info("Inline variable at range: \(range)")
        // Implementation would inline variable usage
    }

    private func performToggleBreakpoint(at range: NSRange, in _: CodeEditorView?) {
        logger.info("Toggle breakpoint at range: \(range)")
        // Implementation would toggle debugger breakpoint
    }

    private func performAddBookmark(at range: NSRange, in _: CodeEditorView?) {
        logger.info("Add bookmark at range: \(range)")
        // Implementation would add navigation bookmark
    }

    private func performGoToLine(in _: CodeEditorView?) {
        logger.info("Go to line requested")
        // Implementation would show go-to-line dialog
    }

    private func performShowAnnotationDetails(at range: NSRange, in _: CodeEditorView?) {
        logger.info("Show annotation details at range: \(range)")
        // Implementation would show detailed annotation info
    }

    private func performQuickFix(at range: NSRange, in _: CodeEditorView?) {
        logger.info("Quick fix at range: \(range)")
        // Implementation would apply automatic fix
    }

    private func performIgnoreWarning(at range: NSRange, in _: CodeEditorView?) {
        logger.info("Ignore warning at range: \(range)")
        // Implementation would suppress warning
    }

    private func performReplace(at range: NSRange, in _: CodeEditorView?) {
        logger.info("Replace at range: \(range)")
        // Implementation would replace current match
    }

    private func performReplaceAll(in _: CodeEditorView?) {
        logger.info("Replace all requested")
        // Implementation would replace all matches
    }
}

// MARK: - Context Menu Builder Extension

extension ContextMenuBuilder {
    /// Get the current number of actions in the builder
    var actionCount: Int {
        actions.count
    }

    /// Add a submenu to the context menu
    /// - Parameters:
    ///   - title: The submenu title
    ///   - actions: The actions for the submenu
    mutating func addSubmenu(title _: String, actions: [ContextMenuAction]) {
        // This would be implemented based on the specific ContextMenuBuilder implementation
        // For now, we'll add the actions directly with a separator
        addSeparator()
        for action in actions {
            addAction(action)
        }
    }
}
