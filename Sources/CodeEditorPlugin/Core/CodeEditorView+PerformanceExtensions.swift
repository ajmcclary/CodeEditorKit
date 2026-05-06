import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - Performance & Memory Management

extension CodeEditorView {
    // MARK: - Performance Optimization

    /// Configure TextKit2 rendering optimizations for large files
    internal func setupTextKit2Optimization() {
        guard let textLayoutManager else { return }

        // Enable viewport-based layout (only lay out visible content)
        // TextKit2 automatically handles viewport-based layout
        textLayoutManager.textViewportLayoutController.delegate = nil // Use default viewport behavior

        // Configure text container for optimal performance
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if let textContainer = self.textContainer {
            // Allow non-contiguous layout for better scrolling performance
            textContainer.widthTracksTextView = true
            textContainer.heightTracksTextView = false

            // Set reasonable line fragment padding
            textContainer.lineFragmentPadding = 4.0
        }
        #elseif targetEnvironment(macCatalyst)
        let textContainer = self.textContainer
        // Allow non-contiguous layout for better scrolling performance
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false

        // Set reasonable line fragment padding
        textContainer.lineFragmentPadding = 4.0
        #endif

        // Configure for hardware acceleration if available
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if let scrollView = enclosingScrollView {
            scrollView.wantsLayer = true
            scrollView.canDrawSubviewsIntoLayer = true
        }
        wantsLayer = true
        #elseif canImport(UIKit)
        layer.shouldRasterize = false // Let the system decide
        layer.rasterizationScale = UIKitScreenMetrics.scale(for: self)
        #endif
    }

    // MARK: - Memory Management

    /// Register cleanup handler with the memory monitor
    internal func registerWithMemoryMonitor() {
        // Memory monitoring is now handled by MemoryManagementCoordinator
        // This method is kept for backward compatibility but delegates to the coordinator
        // The coordinator is automatically created as a lazy property and handles all memory management
    }

    /// Unregister from memory monitor  
    internal func unregisterFromMemoryMonitor() {
        // Memory monitoring cleanup is now handled by MemoryManagementCoordinator's deinit
        // This method is kept for backward compatibility
    }

    // MARK: - Visible Range

    /// Get the visible range of text in the text view
    public func visibleRange() -> NSRange {
        let textKitBridge = TextKitBridge(textView: self)
        return textKitBridge.visibleRange ?? NSRange(location: 0, length: text?.count ?? 0)
    }
}
