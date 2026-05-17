#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - AttributedTextElement

/// An attributed string backed text element
package protocol AttributedTextElement: NSTextElement {
    var attributedString: NSAttributedString { get }
}

// MARK: - NSTextParagraph + AttributedTextElement

extension NSTextParagraph: AttributedTextElement {}
