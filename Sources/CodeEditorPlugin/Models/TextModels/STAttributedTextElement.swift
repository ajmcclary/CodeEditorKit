//  Created by Marcin Krzyzanowski
//  https://github.com/krzyzanowskim/STTextView/blob/main/LICENSE.md

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// An attributed string backed text element
package protocol STAttributedTextElement: NSTextElement {
    var attributedString: NSAttributedString { get }
}

extension NSTextParagraph: STAttributedTextElement { }
