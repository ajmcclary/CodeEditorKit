import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

/// Represents an inline annotation in the code editor.
///
/// Annotations are visual markers that appear inline with code to highlight important
/// information such as TODOs, warnings, errors, or custom notes. They are displayed
/// as small badges or icons next to the relevant code.
///
/// ## Creating Annotations
///
/// ```swift
/// // Create a TODO annotation
/// let todoAnnotation = Annotation(
///     range: NSTextRange(location: 100, length: 4),
///     content: "TODO: Implement error handling"
/// )
///
/// // Create with custom ID for tracking
/// let warningAnnotation = Annotation(
///     range: NSTextRange(location: 200, length: 10),
///     content: "WARNING: Deprecated API",
///     id: "warning-001"
/// )
/// ```
///
/// ## Common Use Cases
///
/// - **Development Markers**: TODO, FIXME, HACK comments
/// - **Code Review**: Review comments and suggestions
/// - **Documentation**: Important notes and explanations
/// - **Diagnostics**: Compiler warnings and errors
/// - **Debugging**: Breakpoints and debug notes
///
/// ## Display Customization
///
/// The appearance of annotations is controlled by the `AnnotationsDataSource`
/// which determines how each annotation is rendered based on its content.
///
/// - SeeAlso: `CodeEditorView.addAnnotation(_:)`, `AnnotationsDataSource`
public struct Annotation {
    /// Unique identifier for this annotation
    public let id: String
    /// Text range where the annotation appears
    public let range: NSTextRange
    /// Content of the annotation
    public let content: String

    /// Creates a new annotation.
    ///
    /// - Parameters:
    ///   - range: The text range where the annotation should appear
    ///   - content: The annotation content (e.g., "TODO", "FIXME", custom message)
    ///   - id: Unique identifier for the annotation (auto-generated if not provided)
    ///
    /// - Note: The range must be valid within the text view's content
    public init(range: NSTextRange, content: String, id: String = UUID().uuidString) {
        self.id = id
        self.range = range
        self.content = content
    }
}
