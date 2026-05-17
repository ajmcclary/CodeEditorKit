import CodeEditorCommon
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
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
///     range: NSRange(location: 100, length: 4),
///     content: "TODO: Implement error handling"
/// )
///
/// // Create with custom ID for tracking
/// let warningAnnotation = Annotation(
///     range: NSRange(location: 200, length: 10),
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
public struct Annotation: Sendable {
    /// Unique identifier for this annotation
    public let id: String
    /// Text range where the annotation appears
    public let range: NSRange
    /// Content of the annotation
    public let content: String
    /// Optional explicit severity/category for this annotation. When set,
    /// hosts (and the framework's default badge rendering) should prefer
    /// this over inferring a kind from `content`'s prefix. `nil` preserves
    /// the legacy behavior of inferring from the content string.
    public let kind: AnnotationKind?

    /// Creates a new annotation.
    ///
    /// - Parameters:
    ///   - range: The text range where the annotation should appear
    ///   - content: The annotation content (e.g., "TODO", "FIXME", custom message)
    ///   - id: Unique identifier for the annotation (auto-generated if not provided)
    ///   - kind: Optional explicit `AnnotationKind`. Pass this to avoid
    ///     content-prefix smuggling (e.g., `"ERROR: …"`) when the host
    ///     already knows the severity. Defaults to `nil`, in which case
    ///     consumers fall back to inferring the kind from `content`.
    ///
    /// - Note: The range must be valid within the text view's content
    public init(
        range: NSRange,
        content: String,
        id: String = UUID().uuidString,
        kind: AnnotationKind? = nil
    ) {
        self.id = id
        self.range = range
        self.content = content
        self.kind = kind
    }

    /// Creates a new annotation from a TextKit range by converting it to a
    /// stable UTF-16 `NSRange` at the boundary.
    ///
    /// - Parameters:
    ///   - range: The text range where the annotation should appear
    ///   - content: The annotation content (e.g., "TODO", "FIXME", custom message)
    ///   - id: Unique identifier for the annotation (auto-generated if not provided)
    ///   - kind: Optional explicit `AnnotationKind`. See `init(range:content:id:kind:)`.
    public init(
        range textRange: NSTextRange,
        content: String,
        id: String = UUID().uuidString,
        kind: AnnotationKind? = nil
    ) {
        self.init(range: NSRange(textRange) ?? .notFound, content: content, id: id, kind: kind)
    }

    /// The annotation's effective kind. Returns the explicit `kind` when
    /// the host supplied one, otherwise falls back to
    /// `AnnotationKind.infer(from: content)` so legacy callers that
    /// smuggle the kind through a content prefix keep working.
    public var resolvedKind: AnnotationKind {
        kind ?? AnnotationKind.infer(from: content)
    }
}
