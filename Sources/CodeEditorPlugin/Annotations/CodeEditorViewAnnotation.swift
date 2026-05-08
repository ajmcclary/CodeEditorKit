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

    /// Creates a new code editor view annotation
    /// - Parameters:
    ///   - location: Location in the text
    ///   - content: Annotation content
    ///   - id: Unique identifier (defaults to new UUID)
    public init(location: NSTextLocation, content: String, id: String = UUID().uuidString) {
        self.id = id
        self.location = location
        self.content = content
    }
}
