#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - MessageLineAnnotation

open class MessageLineAnnotation: LineAnnotation {
    public enum AnnotationKind {
        case info
        case warning
        case error
    }

    open var id: String
    open var location: NSTextLocation
    public let message: AttributedString
    public let kind: AnnotationKind

    public init(id: String, message: AttributedString, kind: AnnotationKind, location: NSTextLocation) {
        self.id = id
        self.message = message
        self.kind = kind
        self.location = location
    }

    deinit {
        // Cleanup if needed
    }
}
