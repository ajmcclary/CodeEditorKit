import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
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
    @MainActor
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
    @MainActor
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
    @MainActor
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
    @MainActor
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
    @MainActor
    public func reloadAnnotations() {
        updateAnnotationViews()
    }

    // MARK: - Private Methods

    @MainActor
    private func updateAnnotationView(for annotation: Annotation) {
        // Remove existing view if any
        if let existingView = annotationViews[annotation.id] {
            existingView.removeFromSuperview()
        }

        // Create new annotation view using data source
        guard let dataSource = annotationsDataSource else {
            return
        }

        // Check if we're using TextKit2
        guard let textLayoutManager else {
            return
        }

        // Convert Annotation to CodeEditorViewAnnotation
        let textViewAnnotation = CodeEditorViewAnnotation(
            location: annotation.range.location,
            content: annotation.content,
            id: annotation.id
        )

        // Ensure layout for the annotation range
        textLayoutManager.ensureLayout(for: annotation.range)

        // Get text layout fragment for the annotation location
        guard let textLayoutFragment = textLayoutManager.textLayoutFragment(for: annotation.range.location) else {
            return
        }

        guard let textLineFragment = textLayoutFragment.textLineFragment(at: annotation.range.location) else {
            return
        }

        // Get the exact text segment frame for the annotation range
        guard let segmentFrame = textLayoutManager.textSegmentFrame(
            in: annotation.range,
            type: .standard
        ) else {
            return
        }

        // Calculate inline annotation position using configuration values
        let badgeSize = configuration.layout.annotationBadgeSize
        let badgePadding = configuration.layout.annotationBadgePadding
        #if canImport(AppKit)
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

        // Create annotation view
        if let annotationView = dataSource.textView(
            self,
            viewForLineAnnotation: textViewAnnotation,
            textLineFragment: textLineFragment,
            proposedViewFrame: proposedFrame
        ) {
            addSubview(annotationView)
            annotationViews[annotation.id] = annotationView

            // Force view update
            #if canImport(AppKit)
            annotationView.needsDisplay = true
            needsDisplay = true
            #else
            annotationView.setNeedsDisplay()
            setNeedsDisplay()
            #endif
        }
    }

    /// Update all annotation views (called during layout)
    @MainActor
    internal func updateAnnotationViews() {
        for annotation in annotations {
            updateAnnotationView(for: annotation)
        }
    }
}
