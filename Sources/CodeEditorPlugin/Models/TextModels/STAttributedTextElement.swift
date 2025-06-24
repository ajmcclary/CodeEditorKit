#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

// MARK: - STAttributedTextElement

/// An attributed string backed text element
package protocol STAttributedTextElement: NSTextElement {
    var attributedString: NSAttributedString { get }
}

// MARK: - NSTextParagraph + STAttributedTextElement

extension NSTextParagraph: STAttributedTextElement {}
