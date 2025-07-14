import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - CompletionViewControllerBase

/// Base class for completion view controllers that provides shared functionality
/// across platforms while allowing platform-specific customization
@MainActor
open class CompletionViewControllerBase: PlatformViewController {
    // MARK: - Public Properties

    public var items: [any CompletionItemView] = [] {
        didSet {
            updateCompletionItems()
        }
    }

    public weak var delegate: CompletionViewControllerDelegate?

    public var completionItems: [CompletionItemModel] = [] {
        didSet {
            reloadData()
            updateSelection()
        }
    }

    // MARK: - Protected Properties

    internal var selectedIndex: Int = 0

    // MARK: - Abstract Methods (to be overridden)

    /// Reload the table/collection data
    open func reloadData() {
        // Default implementation - subclasses should override
    }

    /// Update the selection UI
    open func updateSelection() {
        setSelectedIndex(selectedIndex)
    }

    /// Configure the appearance of the view
    open func configureAppearance() {
        // Base appearance configuration
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        view.wantsLayer = true
        #endif

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        view.layer?.backgroundColor = PlatformColors.controlBackground.cgColor
        view.layer?.cornerRadius = 6
        view.layer?.borderWidth = 1
        view.layer?.borderColor = PlatformColors.separator.cgColor

        // Add shadow
        view.shadow = NSShadow()
        view.layer?.shadowColor = PlatformColors.black.cgColor
        view.layer?.shadowOpacity = 0.2
        view.layer?.shadowOffset = NSSize(width: 0, height: -2)
        view.layer?.shadowRadius = 4
        #else
        view.backgroundColor = PlatformColors.systemBackground
        view.layer.cornerRadius = 8
        view.layer.borderWidth = 1
        view.layer.borderColor = PlatformColors.separator.cgColor

        // Add shadow
        view.layer.shadowColor = PlatformColors.black.cgColor
        view.layer.shadowOpacity = 0.2
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        #endif
    }

    // MARK: - Shared Methods

    /// Update completion items from legacy items
    public func updateCompletionItems() {
        // Convert legacy CompletionItem to CompletionItemModel if needed
        reloadData()
        updateSelection()
    }

    /// Set the selected completion item index
    public func setSelectedIndex(_ index: Int) {
        guard index >= 0 && index < completionItems.count else { return }
        selectedIndex = index
    }

    /// Get the currently selected completion item
    public func selectedCompletionItem() -> CompletionItemModel? {
        guard selectedIndex >= 0 && selectedIndex < completionItems.count else { return nil }
        return completionItems[selectedIndex]
    }

    /// Insert the selected completion item
    public func insertSelectedItem() {
        guard selectedCompletionItem() != nil else { return }
        // Note: Subclasses should override this method to implement their own insertion logic
    }

    // MARK: - Navigation

    /// Move selection up
    public func selectPrevious() {
        if selectedIndex > 0 {
            setSelectedIndex(selectedIndex - 1)
        }
    }

    /// Move selection down
    public func selectNext() {
        if selectedIndex < completionItems.count - 1 {
            setSelectedIndex(selectedIndex + 1)
        }
    }

    // MARK: - Size Calculation

    /// Calculate the preferred size for the completion window
    public func preferredContentSize() -> CGSize {
        let itemCount = min(completionItems.count, 10) // Show max 10 items
        let rowHeight: CGFloat = platformRowHeight()
        let height = CGFloat(itemCount) * rowHeight + 20 // Add padding
        return CGSize(width: 300, height: height)
    }

    /// Get platform-specific row height
    internal func platformRowHeight() -> CGFloat {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return 24
        #else
        return 44
        #endif
    }

    deinit {
        // Clean up any resources
    }
}
