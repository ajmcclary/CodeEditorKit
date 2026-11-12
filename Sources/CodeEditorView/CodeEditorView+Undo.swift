import Foundation

#if canImport(AppKit)
import AppKit

// MARK: - Undo

extension CodeEditorView {
    override public func didChangeText() {
        textChangeGenerationAtLastDidChangeText = textChangeEventGeneration
        super.didChangeText()
    }

    /// A TextKit 2 `NSTextView` applies an undo or redo to its storage without
    /// calling `didChangeText()`, so neither `NSText.didChangeNotification`
    /// nor the delegate's `textDidChange` fires and a host that mirrors the
    /// text never hears about it. Watch the undo manager and post the change
    /// when an undo or redo edited characters that were not announced.
    internal func installUndoChangeObservers() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(undoManagerDidApplyChange(_:)),
            name: .NSUndoManagerDidUndoChange,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(undoManagerDidApplyChange(_:)),
            name: .NSUndoManagerDidRedoChange,
            object: nil
        )
    }

    @objc
    private func undoManagerDidApplyChange(_ notification: Notification) {
        guard let manager = notification.object as? UndoManager,
              manager === undoManager,
              textChangeEventGeneration != textChangeGenerationAtLastDidChangeText
        else { return }
        didChangeText()
    }
}
#endif
