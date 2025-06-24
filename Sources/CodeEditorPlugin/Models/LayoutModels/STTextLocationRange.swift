//  Created by Marcin Krzyzanowski
//  https://github.com/krzyzanowskim/STTextView/blob/main/LICENSE.md

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
internal class STTextLocationRange: UITextRange {
    let textRange: NSTextRange

    init(textRange: NSTextRange) {
        self.textRange = textRange
        super.init()
    }

    override var debugDescription: String {
        textRange.description
    }

    override var start: UITextPosition {
        textRange.location.uiTextPosition
    }

    override var end: UITextPosition {
        textRange.endLocation.uiTextPosition
    }

    override var isEmpty: Bool {
        textRange.isEmpty
    }
}

internal extension UITextRange {
    var nsTextRange: NSTextRange {
        guard let range = self as? STTextLocationRange else {
            fatalError("Invalid type")
        }
        return range.textRange
    }
}
#else
// macOS equivalent - UITextRange doesn't exist on macOS
internal class STTextLocationRange {
    let textRange: NSTextRange

    init(textRange: NSTextRange) {
        self.textRange = textRange
    }

    var debugDescription: String {
        textRange.description
    }

    var start: STTextLocation {
        textRange.location.uiTextPosition
    }

    var end: STTextLocation {
        textRange.endLocation.uiTextPosition
    }

    var isEmpty: Bool {
        textRange.isEmpty
    }
}
#endif

internal extension NSTextRange {
    var uiTextRange: STTextLocationRange {
        STTextLocationRange(textRange: self)
    }
}