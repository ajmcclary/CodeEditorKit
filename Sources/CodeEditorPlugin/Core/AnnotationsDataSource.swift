import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - AnnotationsDataSource

/// Data source for text annotations
public protocol AnnotationsDataSource: AnyObject {
    /// Returns the annotations for the given text range
    func annotations(for textRange: NSTextRange) -> [Annotation]

    /// All annotations
    var textViewAnnotations: [CodeEditorViewAnnotation] { get }

    /// Create a view for the given annotation
    func textView(
        _ textView: CodeEditorView,
        viewForLineAnnotation annotation: CodeEditorViewAnnotation,
        textLineFragment: NSTextLineFragment,
        proposedViewFrame: CGRect
    ) -> NSView?
}
