import CodeEditorPlatform
#if canImport(AppKit)
import AppKit

extension CodeEditorView {
    override open func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { publishEvent(.didBecomeFirstResponder) }
        return became
    }

    override open func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { publishEvent(.didResignFirstResponder) }
        return resigned
    }
}
#elseif canImport(UIKit)
import UIKit

extension CodeEditorView {
    override open func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { publishEvent(.didBecomeFirstResponder) }
        return became
    }

    override open func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { publishEvent(.didResignFirstResponder) }
        return resigned
    }
}
#endif
