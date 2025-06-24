#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
class STTextLocationRange: UITextRange {
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

    deinit {
        // Cleanup if needed
    }
}

extension UITextRange {
    var nsTextRange: NSTextRange {
        guard let range = self as? STTextLocationRange else {
            fatalError("Invalid type")
        }
        return range.textRange
    }
}
#else
/// macOS equivalent - UITextRange doesn't exist on macOS
class STTextLocationRange {
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

    deinit {
        // Cleanup if needed
    }
}
#endif

extension NSTextRange {
    var uiTextRange: STTextLocationRange {
        STTextLocationRange(textRange: self)
    }
}
