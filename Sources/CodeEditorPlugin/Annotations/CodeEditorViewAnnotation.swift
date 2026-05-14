import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Represents an annotation with location in text view
public struct CodeEditorViewAnnotation {
    /// Unique identifier for this annotation
    public var id: String
    /// Location in the text where this annotation appears
    public var location: NSTextLocation
    /// Content of the annotation
    public var content: String
    /// Optional explicit severity/category propagated from the source
    /// `Annotation`. When `nil`, consumers should fall back to
    /// `AnnotationKind.infer(from: content)`.
    public var kind: AnnotationKind?

    /// Creates a new code editor view annotation
    /// - Parameters:
    ///   - location: Location in the text
    ///   - content: Annotation content
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - kind: Optional explicit `AnnotationKind`; mirrors the source
    ///     `Annotation`'s `kind` field. Defaults to `nil`.
    public init(
        location: NSTextLocation,
        content: String,
        id: String = UUID().uuidString,
        kind: AnnotationKind? = nil
    ) {
        self.id = id
        self.location = location
        self.content = content
        self.kind = kind
    }

    /// Creates a new code editor view annotation from a UTF-16 location.
    /// - Parameters:
    ///   - utf16Location: Location in the text
    ///   - content: Annotation content
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - kind: Optional explicit `AnnotationKind`. See `init(location:content:id:kind:)`.
    public init(
        utf16Location: Int,
        content: String,
        id: String = UUID().uuidString,
        kind: AnnotationKind? = nil
    ) {
        self.init(
            location: UTF16TextLocation(value: utf16Location),
            content: content,
            id: id,
            kind: kind
        )
    }
}
