import Foundation
import os.log
#if canImport(UIKit)
import UIKit

// MARK: - UIKit-specific extensions for CodeEditorContainerView

extension CodeEditorContainerView {
    /// Sets up the iOS-specific views and constraints
    func setupIOSViews() {
        // Add gutter view (iOS uses a separate view instead of ruler)
        if configuration.display.showLineNumbers {
            addSubview(gutterView)
            
            // Position gutter view to the left of content
            gutterView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                gutterView.leadingAnchor.constraint(equalTo: leadingAnchor),
                gutterView.topAnchor.constraint(equalTo: topAnchor),
                gutterView.bottomAnchor.constraint(equalTo: bottomAnchor),
                gutterView.widthAnchor.constraint(equalToConstant: configuration.layout.gutterWidth)
            ])
        }
        
        // Add text view with scroll view
        addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure text view constraints
        let leadingConstraint = configuration.display.showLineNumbers ?
            textView.leadingAnchor.constraint(equalTo: gutterView.trailingAnchor) :
            textView.leadingAnchor.constraint(equalTo: leadingAnchor)
        
        NSLayoutConstraint.activate([
            leadingConstraint,
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // Set the text view's delegate
        textView.delegate = self
        
        // Apply configuration
        configuration.apply(to: textView)
        
        // Configure gutter
        gutterView.textView = textView
        // GutterView configuration is handled through the parent container
    }
    
    /// Updates the iOS-specific gutter view with new configuration
    func updateIOSGutter() {
        kUIKitContainerLogger
            .debug(
                "🔧 updateIOSGutter called, showLineNumbers: \(self.configuration.display.showLineNumbers)"
            )
        
        gutterView.isHidden = !configuration.display.showLineNumbers
        
        if configuration.display.showLineNumbers {
            // Update gutter width constraint
            var foundWidthConstraint = false
            for constraint in gutterView.constraints where constraint.firstAttribute == .width {
                constraint.constant = configuration.layout.gutterWidth
                foundWidthConstraint = true
                kUIKitContainerLogger
                    .debug(
                        "🔧 Updated gutter width constraint to: \(self.configuration.layout.gutterWidth)"
                    )
            }
            
            if !foundWidthConstraint {
                kUIKitContainerLogger.debug("⚠️ No width constraint found for gutter view")
            }
            
            // GutterView configuration is handled through the parent container
            gutterView.setNeedsDisplay()
        }
        
        // Update text view leading constraint
        var foundLeadingConstraint = false
        for constraint in textView.constraints where constraint.firstAttribute == .leading {
            constraint.constant = configuration.display.showLineNumbers ? 0 : -configuration.layout.gutterWidth
            foundLeadingConstraint = true
            kUIKitContainerLogger.debug("🔧 Updated text view leading constraint to: \(constraint.constant)")
        }
        
        if !foundLeadingConstraint {
            kUIKitContainerLogger.debug("⚠️ No leading constraint found for text view")
        }
    }
    
    /// Layout views using UIKit-specific logic  
    func layoutViewsUIKit() {
        // Calculate layout dimensions
        let gutterWidth = configuration.layout.gutterWidth
        let minimapWidth = configuration.display.showMinimap ? configuration.layout.minimapWidth : 0
        
        // Position content view to fill the container
        contentView.frame = bounds
        
        // Position gutter on the left - account for content insets
        let contentInsetTop = textView.contentInset.top
        let contentInsetBottom = textView.contentInset.bottom
        let availableHeight = bounds.height - contentInsetTop - contentInsetBottom
        
        gutterView.frame = CGRect(
            x: 0,
            y: contentInsetTop,  // Start after top content inset
            width: gutterWidth,
            height: availableHeight  // Adjust height for content insets
        )
        
        // Position minimap on the right - fixed position
        if configuration.display.showMinimap {
            minimapView.frame = CGRect(
                x: bounds.width - minimapWidth,
                y: 0,
                width: minimapWidth,
                height: bounds.height
            )
            minimapView.isHidden = false
        } else {
            minimapView.isHidden = true
        }
        
        // Position text view within content view to take remaining space between gutter and minimap
        let textViewX = configuration.display.showLineNumbers ? gutterWidth : 0
        let textViewWidth = bounds.width - textViewX - minimapWidth
        textView.frame = CGRect(
            x: textViewX,  // Text view starts after the gutter
            y: contentInsetTop,  // Start after top content inset
            width: textViewWidth,
            height: availableHeight  // Match gutter height
        )
        
        // Ensure content insets are maintained
        updateContentInsets()
    }
}

// MARK: - UITextViewDelegate

extension CodeEditorContainerView: UITextViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Update minimap when text view scrolls
        updateMinimap()
        
        // Don't move the gutter view - keep it fixed in position
        // The gutter will adjust its drawing based on the text view's scroll offset
        
        // Notify the gutter view to update line numbers
        gutterView.setNeedsDisplayLineNumbers()
        
        // Call the gutter's scroll method directly to activate display link
        gutterView.scrollViewDidScroll(scrollView)
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // Start updating line numbers when scrolling begins
        // This helps activate the display link earlier for smoother updates
        gutterView.scrollViewWillBeginDragging(scrollView)
    }
    
    public func scrollViewDidEndDragging(_: UIScrollView, willDecelerate decelerate: Bool) {
        // Continue updating if decelerating
        if !decelerate {
            // Scrolling has stopped, ensure final update
            gutterView.setNeedsDisplayLineNumbers()
        }
    }
    
    public func scrollViewDidEndDecelerating(_: UIScrollView) {
        // Scrolling has completely stopped
        gutterView.setNeedsDisplayLineNumbers()
    }
}

// Private logger instance
private let kUIKitContainerLogger = Logger(subsystem: "com.codeeditor.plugin", category: "CodeEditorContainerView.UIKit")

#endif
