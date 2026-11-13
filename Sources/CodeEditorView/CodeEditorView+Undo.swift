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

// MARK: - Undoable whole-text edits

extension CodeEditorView {
    /// Replaces the text with `text` through the editing path that records
    /// undo and posts the change, touching only the span that differs (the
    /// common prefix and suffix stay). For host rewrites of the editor's own
    /// change, which must neither drop nor invalidate the undo history.
    /// The differing span between `old` and `new` as UTF-16 ranges in each,
    /// from their common prefix and suffix, with both ends widened to
    /// composed-character boundaries in both texts: a span edge inside a
    /// surrogate pair, a ZWJ sequence, a flag, a combining sequence or a CRLF
    /// would split it (and lone surrogates decode as U+FFFD).
    package nonisolated static func changedSpan(from old: String, to new: String) -> (old: NSRange, new: NSRange) {
        // swiftlint:disable:next legacy_objc_type
        let oldText = old as NSString
        // swiftlint:disable:next legacy_objc_type
        let newText = new as NSString
        let oldLength = oldText.length
        let newLength = newText.length
        var prefix = 0
        while prefix < oldLength, prefix < newLength,
              oldText.character(at: prefix) == newText.character(at: prefix) {
            prefix += 1
        }
        var suffix = 0
        while suffix < oldLength - prefix, suffix < newLength - prefix,
              oldText.character(at: oldLength - 1 - suffix) == newText.character(at: newLength - 1 - suffix) {
            suffix += 1
        }

        // Widen until both ends are boundaries in both texts (moving one end
        // in one text can expose a sequence in the other).
        var changed = true
        while changed {
            changed = false
            for text in [oldText, newText] where prefix > 0 && prefix < text.length {
                let start = text.rangeOfComposedCharacterSequence(at: prefix).location
                if start < prefix {
                    prefix = start
                    changed = true
                }
            }
            for (text, length) in [(oldText, oldLength), (newText, newLength)] {
                let end = length - suffix
                guard end > prefix, end < length else { continue }
                let sequence = text.rangeOfComposedCharacterSequence(at: end)
                if sequence.location < end {
                    suffix = length - NSMaxRange(sequence)
                    changed = true
                }
            }
            suffix = min(suffix, oldLength - prefix, newLength - prefix)
        }
        return (
            NSRange(location: prefix, length: oldLength - prefix - suffix),
            NSRange(location: prefix, length: newLength - prefix - suffix)
        )
    }

    package func applyAsUndoableEdit(_ text: String) {
        #if canImport(AppKit)
        let current = string
        #else
        let current = self.text ?? ""
        #endif
        guard current != text else { return }
        let span = Self.changedSpan(from: current, to: text)
        let range = span.old
        // swiftlint:disable:next legacy_objc_type
        let replacement = (text as NSString).substring(with: span.new)
        #if canImport(AppKit)
        guard shouldChangeText(in: range, replacementString: replacement) else { return }
        textKitBridge.replaceCharacters(in: range, with: replacement)
        didChangeText()
        #else
        guard let start = position(from: beginningOfDocument, offset: range.location),
              let end = position(from: start, offset: range.length),
              let textRange = textRange(from: start, to: end) else { return }
        replace(textRange, withText: replacement)
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
