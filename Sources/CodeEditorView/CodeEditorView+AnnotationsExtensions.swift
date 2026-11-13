import CodeEditorAnnotations
import CodeEditorCommon
import CodeEditorPlatform
import CodeEditorTextModel
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
        for annotation in annotations {
            updateAnnotationView(for: annotation)
        }
        annotationLayoutKey = currentAnnotationLayoutKey()
    }

    // MARK: - Private Methods

    @MainActor
    private func updateAnnotationView(for annotation: Annotation) {
        // Remove existing view if any
        if let existingView = annotationViews[annotation.id] {
            existingView.removeFromSuperview()
        }

        // Hidden, not discarded: turning annotations back on redraws them.
        guard configuration.display.areAnnotationsEnabled else {
            annotationViews[annotation.id] = nil
            return
        }

        // Create new annotation view using data source
        guard let dataSource = annotationsDataSource else {
            return
        }

        // TextKit 2 places the badge; nothing is shown without it.
        guard let placement = annotationPlacement(for: annotation) else { return }

        // Create annotation view
        if let annotationView = dataSource.textView(
            self,
            viewForLineAnnotation: placement.annotation,
            textLineFragment: placement.lineFragment,
            proposedViewFrame: placement.frame
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

    /// Where an annotation's badge goes: the view annotation, its line
    /// fragment and the badge frame in this view's coordinates.
    @MainActor
    private func annotationPlacement(
        for annotation: Annotation
    ) -> (annotation: CodeEditorViewAnnotation, lineFragment: NSTextLineFragment, frame: CGRect)? {
        guard let textLayoutManager,
              let textContentManager = textLayoutManager.textContentManager,
              let annotationTextRange = TextRangeUtilities.convert(annotation.range, in: textContentManager) else {
            return nil
        }

        // Convert Annotation to CodeEditorViewAnnotation
        let textViewAnnotation = CodeEditorViewAnnotation(
            location: annotationTextRange.location,
            content: annotation.content,
            id: annotation.id,
            kind: annotation.kind
        )

        // Ensure layout for the annotation range
        textLayoutManager.ensureLayout(for: annotationTextRange)

        // Get text layout fragment for the annotation location
        guard let textLayoutFragment = textLayoutManager.textLayoutFragment(for: annotationTextRange.location),
              let textLineFragment = textLayoutFragment.textLineFragment(at: annotationTextRange.location),
              // Get the exact text segment frame for the annotation range
              let segmentFrame = textLayoutManager.textSegmentFrame(in: annotationTextRange, type: .standard)
        else {
            return nil
        }

        // Calculate inline annotation position using configuration values
        let badgeSize = configuration.layout.annotationBadgeSize
        let badgePadding = configuration.layout.annotationBadgePadding
        #if canImport(AppKit)
        // The segment frame is in the text container's coordinates.
        let containerOrigin = textContainerOrigin
        let inlineX = containerOrigin.x + segmentFrame.maxX + badgePadding
        let inlineY = containerOrigin.y + segmentFrame.midY - (badgeSize / 2)
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
        return (textViewAnnotation, textLineFragment, proposedFrame)
    }

    /// What annotation frames depend on. A layout pass with the same key has
    /// nothing to move.
    internal struct AnnotationLayoutKey: Equatable {
        let textGeneration: UInt64
        let size: CGSize
        let containerOrigin: CGPoint
        let annotationIDs: [String]
        let isEnabled: Bool
    }

    @MainActor
    internal func currentAnnotationLayoutKey() -> AnnotationLayoutKey {
        #if canImport(AppKit)
        let origin = textContainerOrigin
        #else
        let origin = CGPoint(x: textContainerInset.left, y: textContainerInset.top)
        #endif
        return AnnotationLayoutKey(
            textGeneration: textChangeEventGeneration,
            size: frame.size,
            containerOrigin: origin,
            annotationIDs: annotations.map(\.id),
            isEnabled: configuration.display.areAnnotationsEnabled
        )
    }

    /// Update all annotation views (called during layout). Existing views
    /// are moved, not recreated through the data source, and nothing is done
    /// when nothing their frames depend on changed since the last pass.
    @MainActor
    internal func updateAnnotationViews() {
        let key = currentAnnotationLayoutKey()
        guard key != annotationLayoutKey else { return }
        annotationLayoutKey = key

        for annotation in annotations {
            guard configuration.display.areAnnotationsEnabled,
                  let existingView = annotationViews[annotation.id] else {
                updateAnnotationView(for: annotation)
                continue
            }
            if let placement = annotationPlacement(for: annotation),
               existingView.frame != placement.frame {
                existingView.frame = placement.frame
            }
        }
    }
}
