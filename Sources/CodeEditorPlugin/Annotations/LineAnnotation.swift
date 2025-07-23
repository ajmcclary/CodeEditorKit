#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - LineAnnotation

/// Protocol for annotations that can be attached to specific lines in the editor
public protocol LineAnnotation {
    /// Type alias for annotation identifiers
    typealias Identifier = String

    /// Unique identifier for this annotation
    var id: Identifier { get }
    /// Location in the text where this annotation should appear
    var location: any NSTextLocation { get set }
}
