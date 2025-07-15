import Foundation
import ObjectiveC
#if canImport(UIKit)
import UIKit

// MARK: - UIKit-specific extensions for CodeEditorContainerView

extension CodeEditorContainerView {
    // Properties to track constraints - using addresses instead of strings
    private enum AssociatedKeys {
        nonisolated(unsafe) static var textViewConstraints = 0
        nonisolated(unsafe) static var gutterConstraints = 1
        nonisolated(unsafe) static var minimapConstraints = 2
    }
    
    private var textViewConstraints: [NSLayoutConstraint] {
        get {
            objc_getAssociatedObject(self, withUnsafePointer(to: &AssociatedKeys.textViewConstraints) { $0 }) as? [NSLayoutConstraint] ?? []
        }
        set {
            objc_setAssociatedObject(self, withUnsafePointer(to: &AssociatedKeys.textViewConstraints) { $0 }, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private var gutterConstraints: [NSLayoutConstraint] {
        get {
            objc_getAssociatedObject(self, withUnsafePointer(to: &AssociatedKeys.gutterConstraints) { $0 }) as? [NSLayoutConstraint] ?? []
        }
        set {
            objc_setAssociatedObject(self, withUnsafePointer(to: &AssociatedKeys.gutterConstraints) { $0 }, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private var minimapConstraints: [NSLayoutConstraint] {
        get {
            objc_getAssociatedObject(self, withUnsafePointer(to: &AssociatedKeys.minimapConstraints) { $0 }) as? [NSLayoutConstraint] ?? []
        }
        set {
            objc_setAssociatedObject(self, withUnsafePointer(to: &AssociatedKeys.minimapConstraints) { $0 }, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    /// Sets up the iOS-specific views and constraints
    func setupIOSViews() {
        // Clear any existing constraints
        removeExistingConstraints()
        
        // Add all subviews first
        if !gutterView.isDescendant(of: self) {
            addSubview(gutterView)
        }
        if !textView.isDescendant(of: self) {
            addSubview(textView)
        }
        if !minimapView.isDescendant(of: self) {
            addSubview(minimapView)
        }
        
        // Set up autoresizing mask translation
        gutterView.translatesAutoresizingMaskIntoConstraints = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        minimapView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set the text view's delegate
        textView.delegate = self
        
        // Configure gutter
        gutterView.textView = textView
        
        // Apply configuration BEFORE building constraints
        configuration.apply(to: textView)
        
        // Set up constraints based on configuration
        rebuildConstraints()
    }
    
    private func removeExistingConstraints() {
        // Deactivate and remove all tracked constraints
        NSLayoutConstraint.deactivate(textViewConstraints)
        NSLayoutConstraint.deactivate(gutterConstraints)
        NSLayoutConstraint.deactivate(minimapConstraints)
        
        textViewConstraints = []
        gutterConstraints = []
        minimapConstraints = []
    }
    
    func rebuildConstraints() {
        // Remove existing constraints
        removeExistingConstraints()
        
        // Ensure all views are properly added to the hierarchy before creating constraints
        if !textView.isDescendant(of: self) {
            addSubview(textView)
            textView.translatesAutoresizingMaskIntoConstraints = false
        }
        
        if !gutterView.isDescendant(of: self) {
            addSubview(gutterView)
            gutterView.translatesAutoresizingMaskIntoConstraints = false
        }
        
        if !minimapView.isDescendant(of: self) {
            addSubview(minimapView)
            minimapView.translatesAutoresizingMaskIntoConstraints = false
        }
        
        var newGutterConstraints: [NSLayoutConstraint] = []
        var newTextViewConstraints: [NSLayoutConstraint] = []
        var newMinimapConstraints: [NSLayoutConstraint] = []
        
        // Configure gutter constraints if line numbers are shown
        if configuration.display.isLineNumbersEnabled {
            // Ensure gutter is added to view hierarchy
            if gutterView.superview == nil {
                addSubview(gutterView)
                gutterView.translatesAutoresizingMaskIntoConstraints = false
            }
            
            newGutterConstraints = [
                gutterView.leadingAnchor.constraint(equalTo: leadingAnchor),
                gutterView.topAnchor.constraint(equalTo: topAnchor),
                gutterView.bottomAnchor.constraint(equalTo: bottomAnchor),
                gutterView.widthAnchor.constraint(equalToConstant: configuration.layout.gutterWidth)
            ]
            gutterView.isHidden = false
        } else {
            // When line numbers are disabled, hide gutter and set width to 0
            gutterView.isHidden = true
            // Add a zero-width constraint to ensure gutter takes no space
            newGutterConstraints = [
                gutterView.widthAnchor.constraint(equalToConstant: 0)
            ]
        }
        
        // Configure text view constraints
        // Always connect text view directly to container when gutter is hidden
        let textViewLeading = configuration.display.isLineNumbersEnabled ?
            textView.leadingAnchor.constraint(equalTo: gutterView.trailingAnchor) :
            textView.leadingAnchor.constraint(equalTo: leadingAnchor)
        
        let textViewTrailing = configuration.display.showMinimap ?
            textView.trailingAnchor.constraint(equalTo: minimapView.leadingAnchor) :
            textView.trailingAnchor.constraint(equalTo: trailingAnchor)
        
        // Set high priority to ensure constraints are respected
        textViewLeading.priority = .required
        textViewTrailing.priority = .required
        
        newTextViewConstraints = [
            textViewLeading,
            textView.topAnchor.constraint(equalTo: topAnchor),
            textViewTrailing,
            textView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ]
        
        // Configure minimap constraints if minimap is shown
        if configuration.display.showMinimap {
            newMinimapConstraints = [
                minimapView.trailingAnchor.constraint(equalTo: trailingAnchor),
                minimapView.topAnchor.constraint(equalTo: topAnchor),
                minimapView.bottomAnchor.constraint(equalTo: bottomAnchor),
                minimapView.widthAnchor.constraint(equalToConstant: configuration.layout.minimapWidth)
            ]
            minimapView.isHidden = false
            
            // Ensure minimap is on top for event handling
            minimapView.layer.zPosition = 100
            bringSubviewToFront(minimapView)
        } else {
            minimapView.isHidden = true
        }
        
        // Activate and store constraints
        NSLayoutConstraint.activate(newGutterConstraints)
        NSLayoutConstraint.activate(newTextViewConstraints)
        NSLayoutConstraint.activate(newMinimapConstraints)
        
        gutterConstraints = newGutterConstraints
        textViewConstraints = newTextViewConstraints
        minimapConstraints = newMinimapConstraints
    }
    
    /// Updates the iOS-specific gutter view with new configuration
    func updateIOSGutter() {
        // Log is commented out to avoid logger dependency
        // Would log: "🔧 updateIOSGutter called, showLineNumbers: \(self.configuration.display.showLineNumbers), showMinimap: \(self.configuration.display.showMinimap)"
        
        // Rebuild constraints to handle visibility changes
        rebuildConstraints()
        
        // Update gutter display if visible
        if configuration.display.isLineNumbersEnabled {
            gutterView.setNeedsDisplay()
        }
        
        // Update minimap if visible
        if configuration.display.showMinimap {
            updateMinimap()
            // Force minimap to redraw
            minimapView.setNeedsDisplay()
        }
        
        // Force layout update
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    /// Layout views using UIKit-specific logic  
    func layoutViewsUIKit() {
        // Since we're using Auto Layout constraints, we don't need to manually set frames
        // Just ensure visibility and display updates
        
        // Update gutter visibility
        gutterView.isHidden = !configuration.display.isLineNumbersEnabled
        if configuration.display.isLineNumbersEnabled {
            gutterView.setNeedsDisplay()
        }
        
        // Update minimap visibility
        minimapView.isHidden = !configuration.display.showMinimap
        if configuration.display.showMinimap {
            // Force minimap to display
            minimapView.setNeedsDisplay()
            // Ensure it's on top for event handling
            minimapView.layer.zPosition = 100
            bringSubviewToFront(minimapView)
        }
        
        // Let Auto Layout handle the actual positioning
        setNeedsLayout()
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

#endif
