import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

/// Represents an annotation with location in text view
public struct CodeEditorViewAnnotation {
    public var id: String
    public var location: NSTextLocation
    public var content: String

    public init(location: NSTextLocation, content: String, id: String = UUID().uuidString) {
        self.id = id
        self.location = location
        self.content = content
    }
}
