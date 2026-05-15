#if canImport(AppKit)
import AppKit

extension CodeEditorView {
    open override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { publishEvent(.didBecomeFirstResponder) }
        return became
    }

    open override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { publishEvent(.didResignFirstResponder) }
        return resigned
    }
}
#elseif canImport(UIKit)
import UIKit

extension CodeEditorView {
    open override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { publishEvent(.didBecomeFirstResponder) }
        return became
    }

    open override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { publishEvent(.didResignFirstResponder) }
        return resigned
    }
}
#endif
