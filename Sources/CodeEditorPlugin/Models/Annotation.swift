import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

/// Represents an annotation in the text
public struct Annotation {
    public let id: String
    public let range: NSTextRange
    public let content: String

    public init(range: NSTextRange, content: String, id: String = UUID().uuidString) {
        self.id = id
        self.range = range
        self.content = content
    }
}
