import CodeEditorPlatform
import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Cross-platform editing commands and availability.
@MainActor
extension CodeEditorView {
    func performCut() {
        cut(nil)
    }

    func performCopy() {
        copy(nil)
    }

    func performPaste() {
        paste(nil)
    }

    func performSelectAll() {
        selectAll(nil)
    }

    func performDelete() {
        #if canImport(AppKit)
        deleteBackward(nil)
        #else
        deleteBackward()
        #endif
    }

    var canCut: Bool {
        isEditable && currentSelectionRange.length > 0
    }

    var canCopy: Bool {
        currentSelectionRange.length > 0
    }

    var canPaste: Bool {
        guard isEditable else { return false }
        #if canImport(AppKit)
        return NSPasteboard.general.string(forType: .string) != nil
        #else
        return true
        #endif
    }

    private var currentSelectionRange: NSRange {
        #if canImport(AppKit)
        selectedRange()
        #else
        selectedRange
        #endif
    }
}
