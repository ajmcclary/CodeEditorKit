#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
@MainActor
class TextLocationRange: UITextRange {
    let textRange: NSTextRange

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
    let textRange: NSTextRange

    init(textRange: NSTextRange) {
        self.textRange = textRange
    }

    var debugDescription: String {
        textRange.description
    }

    var start: TextLocation {
        textRange.location.uiTextPosition
    }

    var end: TextLocation {
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
    @MainActor
    var uiTextRange: TextLocationRange {
        TextLocationRange(textRange: self)
    }
}
