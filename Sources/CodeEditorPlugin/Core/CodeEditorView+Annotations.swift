import Foundation
import os.log

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - Annotations Support

extension CodeEditorView {
    // MARK: - Public API
    
    /// Adds an annotation to the text view at the specified range.
    ///
    /// Annotations appear as inline badges in the editor with custom content and styling.
    /// Use annotations to display markers for TODOs, warnings, errors, or other inline documentation.
    ///
    /// - Parameter annotation: The annotation to add to the text view
    ///
    /// - Note: The annotation view is created using the `annotationsDataSource` if available.
    ///         Without a data source, the annotation will be stored but not displayed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let annotation = Annotation(
    ///     range: NSRange(location: 10, length: 4),
    ///     content: "TODO",
    ///     kind: .todo
    /// )
    /// editor.addAnnotation(annotation)
    /// ```
    ///
    /// - SeeAlso: `removeAnnotation(withId:)`, `removeAllAnnotations()`, `AnnotationsDataSource`
    public func addAnnotation(_ annotation: Annotation) {
        appendAnnotation(annotation)
        updateAnnotationView(for: annotation)
    }

    /// Removes an annotation with the specified identifier.
    ///
    /// This method removes both the annotation data and its associated view from the text editor.
    ///
    /// - Parameter id: The unique identifier of the annotation to remove
    ///
    /// - Note: If no annotation exists with the given ID, this method does nothing.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Remove a specific annotation
    /// editor.removeAnnotation(withId: "todo-123")
    /// ```
    ///
    /// - SeeAlso: `addAnnotation(_:)`, `removeAllAnnotations()`
    public func removeAnnotation(withId id: String) {
        removeAnnotation { $0.id == id }
        annotationViews[id]?.removeFromSuperview()
        annotationViews.removeValue(forKey: id)
    }
    
    /// Removes an annotation.
    ///
    /// Convenience method for removing an annotation by its instance.
    ///
    /// - Parameter annotation: The annotation to remove
    public func removeAnnotation(_ annotation: Annotation) {
        removeAnnotation(withId: annotation.id)
    }

    /// Removes all annotations from the text view.
    ///
    /// This method clears all annotation data and removes all annotation views from the editor.
    /// Use this method when you need to reset the annotation state or reload annotations.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Clear all annotations before reloading
    /// editor.removeAllAnnotations()
    /// 
    /// // Add new annotations
    /// for annotation in newAnnotations {
    ///     editor.addAnnotation(annotation)
    /// }
    /// ```
    ///
    /// - SeeAlso: `addAnnotation(_:)`, `removeAnnotation(withId:)`
    public func removeAllAnnotations() {
        // Call the internal method to clear the array
        clearAnnotations() 
        // Clear the annotation views
        annotationViews.values.forEach { $0.removeFromSuperview() }
        annotationViews.removeAll()
    }

    /// Returns all annotations currently displayed in the text view.
    ///
    /// Use this property to access the complete list of annotations for persistence,
    /// filtering, or other processing needs.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Filter annotations by kind
    /// let todos = editor.allAnnotations.filter { $0.kind == .todo }
    /// 
    /// // Save annotations for persistence
    /// let annotationData = editor.allAnnotations.map { $0.toDictionary() }
    /// ```
    ///
    /// - Returns: An array of all annotations in the text view
    ///
    /// - SeeAlso: `addAnnotation(_:)`, `Annotation`
    public var allAnnotations: [Annotation] {
        annotations
    }
    
    /// Reload all annotations from the data source.
    ///
    /// This method refreshes the annotation views based on the current annotations or data source.
    /// It should be called after external changes to annotations that require UI updates.
    public func reloadAnnotations() {
        updateAnnotationViews()
    }

    // MARK: - Private Methods
    
    private func updateAnnotationView(for annotation: Annotation) {
        kLogger.debug("updateAnnotationView called for annotation: \(annotation.id)")
        kLogger.debug("- annotation range: \(String(describing: annotation.range))")
        kLogger.debug("- annotation content: \(annotation.content)")
        kLogger.debug("- textLayoutManager exists: \(self.textLayoutManager != nil)")
        kLogger.debug("- annotationsDataSource exists: \(self.annotationsDataSource != nil)")
        
        // Remove existing view if any
        if let existingView = annotationViews[annotation.id] {
            kLogger.debug("Removing existing annotation view")
            existingView.removeFromSuperview()
        }

        // Create new annotation view using data source
        guard let dataSource = annotationsDataSource else {
            kLogger.debug("No annotations data source - annotation will not be displayed")
            return
        }

        // Check if we're using TextKit2
        guard let textLayoutManager else {
            kLogger.debug("No textLayoutManager (not using TextKit2?) - annotation will not be displayed")
            return
        }
        
        kLogger.debug("Using TextKit2 with textLayoutManager")
        
        // Convert Annotation to CodeEditorViewAnnotation
        let textViewAnnotation = CodeEditorViewAnnotation(
            location: annotation.range.location,
            content: annotation.content,
            id: annotation.id
        )

        // Ensure layout for the annotation range
        textLayoutManager.ensureLayout(for: annotation.range)
        kLogger.debug("ensureLayout completed for range")
        
        // Get text layout fragment for the annotation location
        guard let textLayoutFragment = textLayoutManager.textLayoutFragment(for: annotation.range.location) else {
            kLogger.debug("Could not get textLayoutFragment for location: \(String(describing: annotation.range.location))")
            return
        }
        kLogger.debug("Got textLayoutFragment")
        
        guard let textLineFragment = textLayoutFragment.textLineFragment(at: annotation.range.location) else {
            kLogger.debug("Could not get textLineFragment at location: \(String(describing: annotation.range.location))")
            return
        }
        kLogger.debug("Got textLineFragment")

        // Get the exact text segment frame for the annotation range
        guard let segmentFrame = textLayoutManager.textSegmentFrame(
            in: annotation.range,
            type: .standard
        ) else { 
            kLogger.debug("Could not get textSegmentFrame for range: \(String(describing: annotation.range))")
            return 
        }
        kLogger.debug("Got segmentFrame: \(String(describing: segmentFrame))")

        // Calculate inline annotation position using configuration values
        let badgeSize = configuration.layout.annotationBadgeSize
        let badgePadding = configuration.layout.annotationBadgePadding
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let inlineX = textContainerInset.width + segmentFrame.maxX + badgePadding
        let inlineY = textContainerInset.height + segmentFrame.midY - (badgeSize / 2)
        #else
        let inlineX = textContainerInset.left + segmentFrame.maxX + badgePadding
        let inlineY = textContainerInset.top + segmentFrame.midY - (badgeSize / 2)
        #endif
        
        let proposedFrame = CGRect(
            x: inlineX,
            y: inlineY,
            width: badgeSize,
            height: badgeSize
        ).integral
        
        kLogger.debug("Calculated proposedFrame: \(String(describing: proposedFrame))")
        kLogger.debug("textContainerInset: \(String(describing: self.textContainerInset))")

        // Create annotation view
        if let annotationView = dataSource.textView(
            self,
            viewForLineAnnotation: textViewAnnotation,
            textLineFragment: textLineFragment,
            proposedViewFrame: proposedFrame
        ) {
            kLogger.debug("Successfully created annotation view")
            kLogger.debug("Adding annotation view to subview hierarchy")
            kLogger.debug("Current view bounds: \(String(describing: self.bounds))")
            kLogger.debug("Current view subviews count: \(self.subviews.count)")
            
            addSubview(annotationView)
            annotationViews[annotation.id] = annotationView
            
            kLogger.debug("Added annotation view, new subviews count: \(self.subviews.count)")
            
            // Force view update
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            annotationView.needsDisplay = true
            needsDisplay = true
            #else
            annotationView.setNeedsDisplay()
            setNeedsDisplay()
            #endif
        } else {
            kLogger.debug("Data source returned nil annotation view")
        }
    }
    
    /// Update all annotation views (called during layout)
    internal func updateAnnotationViews() {
        kLogger.debug("updateAnnotationViews called, total annotations: \(self.annotations.count)")
        
        for annotation in annotations {
            updateAnnotationView(for: annotation)
        }
    }
}
