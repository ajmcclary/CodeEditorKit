#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
@MainActor
class TextLocationRange: UITextRange {
    package let textRange: NSTextRange

    init(textRange: NSTextRange) {
        self.textRange = textRange
        super.init()
    }

    override var debugDescription: String {
        "TextLocationRange"
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
    var nsTextRange: NSTextRange? {
        (self as? TextLocationRange)?.textRange
    }
}
#else
/// macOS equivalent - UITextRange doesn't exist on macOS
@MainActor
class TextLocationRange {
    package let textRange: NSTextRange

    init(textRange: NSTextRange) {
        self.textRange = textRange
    }

    package var debugDescription: String {
        textRange.description
    }

    package var start: TextLocation {
        textRange.location.uiTextPosition
    }

    package var end: TextLocation {
        textRange.endLocation.uiTextPosition
    }

    package var isEmpty: Bool {
        textRange.isEmpty
    }

    deinit {
        // Cleanup if needed
    }
}
#endif

extension NSTextRange {
    @MainActor
    var uiTextRange: TextLocationRange {
        TextLocationRange(textRange: self)
    }
}
