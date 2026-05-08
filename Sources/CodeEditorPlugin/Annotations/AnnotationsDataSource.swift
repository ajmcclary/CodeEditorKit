import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - AnnotationsDataSource

/// Data source for text annotations.
///
/// Implement this protocol to provide custom annotations to the code editor.
/// The data source is queried when text changes or when layout updates occur.
///
/// ## Overview
///
/// The annotation system supports two workflows:
/// 1. **Simple annotations**: Return `Annotation` objects for basic markers
/// 2. **Custom views**: Provide custom views for advanced annotation displays
///
/// ## Example Implementation
///
/// ```swift
/// class MyAnnotationsDataSource: AnnotationsDataSource {
///     private var annotations: [Annotation] = []
///     
///     func annotations(for textRange: NSTextRange) -> [Annotation] {
///         // Return annotations that intersect with the given range
///         return annotations.filter { annotation in
///             // Check if annotation's range intersects with textRange
///             return rangesIntersect(annotation.range, textRange)
///         }
///     }
///     
///     var textViewAnnotations: [CodeEditorViewAnnotation] {
///         // Convert annotations to view annotations
///         return annotations.map { annotation in
///             CodeEditorViewAnnotation(from: annotation)
///         }
///     }
///     
///     func textView(
///         _ textView: CodeEditorView,
///         viewForLineAnnotation annotation: CodeEditorViewAnnotation,
///         textLineFragment: NSTextLineFragment,
///         proposedViewFrame: CGRect
///     ) -> PlatformView? {
///         // Create custom view for annotation
///         let view = createAnnotationView(for: annotation)
///         view.frame = proposedViewFrame
///         return view
///     }
/// }
/// ```
///
/// ## Integration
///
/// ```swift
/// let dataSource = MyAnnotationsDataSource()
/// editor.annotationsDataSource = dataSource
/// 
/// // Update annotations
/// dataSource.updateAnnotations(newAnnotations)
/// editor.reloadAnnotations()
/// ```
///
/// - SeeAlso: ``Annotation``, ``CodeEditorViewAnnotation``, ``CodeEditorView/annotationsDataSource``
public protocol AnnotationsDataSource: AnyObject {
    /// Returns the annotations for the given text range.
    ///
    /// This method is called during layout to determine which annotations
    /// should be displayed for visible text. Only return annotations that
    /// intersect with the provided range for optimal performance.
    ///
    /// - Parameter textRange: The range of text being laid out
    /// - Returns: Array of annotations that should be displayed in this range
    func annotations(for textRange: NSTextRange) -> [Annotation]

    /// All annotations managed by this data source.
    ///
    /// This property provides all annotations as view-compatible objects.
    /// The returned annotations should be properly configured for display.
    ///
    /// - Note: This may be called frequently, so consider caching the result.
    var textViewAnnotations: [CodeEditorViewAnnotation] { get }

    /// Create a view for the given annotation.
    ///
    /// Implement this method to provide custom views for your annotations.
    /// The view will be positioned according to the proposed frame.
    ///
    /// - Parameters:
    ///   - textView: The code editor requesting the view
    ///   - annotation: The annotation to display
    ///   - textLineFragment: The line fragment containing the annotation
    ///   - proposedViewFrame: The suggested frame for the annotation view
    /// - Returns: A custom view for the annotation, or nil to use default rendering
    ///
    /// - Note: The returned view should respect the proposed frame for proper layout.
    func textView(
        _ textView: CodeEditorView,
        viewForLineAnnotation annotation: CodeEditorViewAnnotation,
        textLineFragment: NSTextLineFragment,
        proposedViewFrame: CGRect
    ) -> PlatformView?
}
