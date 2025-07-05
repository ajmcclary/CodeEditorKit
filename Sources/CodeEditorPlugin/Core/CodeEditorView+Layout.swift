import Foundation
import os.log

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - Layout & Paragraph Style

extension CodeEditorView {
    // MARK: - Paragraph Style
    
    /// Apply paragraph style settings for tab width and line spacing
    internal func applyParagraphStyle() {
        // Create a new paragraph style with the configured settings
        let paragraphStyle = NSMutableParagraphStyle()
        
        // Set line spacing multiplier
        paragraphStyle.lineHeightMultiple = configuration.layout.lineSpacing
        
        // Set tab stops based on tab width
        let tabWidth = CGFloat(configuration.layout.tabWidth)
        let font = self.font ?? PlatformFonts.monospacedSystemFont(ofSize: configuration.display.fontSize, weight: .regular)
        let spaceWidth = "    ".size(withAttributes: [.font: font]).width / 4.0 // Width of one space
        let tabInterval = spaceWidth * tabWidth
        
        // Clear existing tab stops and set new ones
        paragraphStyle.tabStops = []
        var tabPosition: CGFloat = tabInterval
        for _ in 0..<50 { // Create enough tab stops for reasonable content
            let tabStop = NSTextTab(textAlignment: .left, location: tabPosition, options: [:])
            paragraphStyle.tabStops.append(tabStop)
            tabPosition += tabInterval
        }
        
        // Set default tab interval
        paragraphStyle.defaultTabInterval = tabInterval
        
        // Apply the paragraph style to all text
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if let textStorage = self.textStorage {
            let range = NSRange(location: 0, length: textStorage.length)
            textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
            
            // Set as default paragraph style for new text
            defaultParagraphStyle = paragraphStyle
        }
        #else
        let textStorage = self.textStorage
        let range = NSRange(location: 0, length: textStorage.length)
        textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        
        // Set as typing attributes for new text
        var typingAttrs = typingAttributes
        typingAttrs[.paragraphStyle] = paragraphStyle
        typingAttributes = typingAttrs
        #endif
        
        // Force text view to relayout and redraw
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        needsDisplay = true
        needsLayout = true
        #else
        setNeedsDisplay()
        setNeedsLayout()
        #endif
    }
    
    // MARK: - Layout Overrides
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public func layout() {
        // Ensure we're on the main thread for layout operations
        if Thread.isMainThread {
            super.layout()
            updateGutterFrame()
            updateLineHighlightFrame()
            updateAnnotationViews()
        } else {
            // Use Swift concurrency to dispatch to main actor
            Task { @MainActor [weak self] in
                self?.layout()
            }
        }
    }
    #else
    override public func layoutSubviews() {
        super.layoutSubviews()
        updateGutterFrame()
        updateLineHighlightFrame()
        updateAnnotationViews()
    }
    #endif

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        updateGutterFrame()
    }
    #endif

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateGutterFrame()
    }
    #endif
    
    // MARK: - Text Container Origin
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// Override textContainerOrigin to account for ruler view when using NSScrollView
    override public var textContainerOrigin: NSPoint {
        let origin = super.textContainerOrigin
        
        // Check if we're in a scroll view with a ruler view
        if let scrollView = self.enclosingScrollView,
           scrollView.hasVerticalRuler && scrollView.rulersVisible,
           scrollView.verticalRulerView != nil {
            // Don't offset the origin - the ruler sits alongside the text view
            // The text container inset handles the internal padding
            // This prevents double offsetting
        }
        
        return origin
    }
    #endif
}
