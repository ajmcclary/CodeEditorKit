import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Undo history

extension CodeEditorView {
    /// Discards this editor's undo and redo actions — for when its text was
    /// replaced wholesale, so recorded offsets no longer describe it. Leaves a
    /// host-supplied (shared) undo manager alone on macOS; on iOS the text
    /// view's undo manager is its own.
    package func discardUndoHistory() {
        #if canImport(AppKit)
        guard undoManager === editorUndoManager else { return }
        editorUndoManager.removeAllActions()
        #else
        undoManager?.removeAllActions()
        #endif
    }
}

#if canImport(AppKit)

// MARK: - Undo notifications

extension CodeEditorView {
    override open func didChangeText() {
        textChangeGenerationAtLastDidChangeText = textChangeEventGeneration
        super.didChangeText()
    }

    /// A TextKit 2 `NSTextView` applies an undo or redo to its storage without
    /// calling `didChangeText()`, so neither `NSText.didChangeNotification`
    /// nor the delegate's `textDidChange` fires and a host that mirrors the
    /// text never hears about it. Watch the undo manager and post the change
    /// when an undo or redo edited characters that were not announced.
    ///
    /// Only the editor's own undo manager is observed (it is the notification
    /// object), so undos on other managers anywhere in the process never
    /// reach this view. A participant-supplied undo manager is not observed.
    internal func installUndoChangeObservers() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(undoManagerDidApplyChange(_:)),
            name: .NSUndoManagerDidUndoChange,
            object: editorUndoManager
        )
        center.addObserver(
            self,
            selector: #selector(undoManagerDidApplyChange(_:)),
            name: .NSUndoManagerDidRedoChange,
            object: editorUndoManager
        )
    }

    /// Notifications arrive on the posting thread. The editor's own undo
    /// manager is driven from the main thread; anything else is ignored
    /// rather than entering main-actor state from another thread.
    @objc
    nonisolated private func undoManagerDidApplyChange(_: Notification) {
        guard Thread.isMainThread else { return }
        MainActor.assumeIsolated {
            guard undoManager === editorUndoManager,
                  textChangeEventGeneration != textChangeGenerationAtLastDidChangeText
            else { return }
            didChangeText()
        }
    }
}
#endif
