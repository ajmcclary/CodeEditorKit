import CodeEditorPlatform
import CodeEditorTextModel
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Syntax Highlighting

extension CodeEditorView {
    // MARK: - Notification Handlers

    @objc
    internal func handleTextStorageDidProcessEditing(_ notification: Notification) {
        // The observer is registered without an `object:` filter (see
        // `TextKitSetupHelper.setupNotifications` — filtering on
        // `textView.textStorage` would trigger Apple's TK1 compatibility
        // shim). Validate the sender against the TK2-safe accessor here.
        guard let textStorage = notification.object as? NSTextStorage,
              textStorage === self.textContentStorage?.textStorage
        else {
            return
        }

        // Snapshot edit state synchronously — these accessors are safe inside the
        // didProcessEditingNotification callback. Anything that **reacts** to the
        // edit (publishes events, enumerates layout fragments, re-enters
        // beginEditing) must run AFTER the NSTextContentStorage transaction
        // closes; see the deferred dispatch below.
        let editedMask = textStorage.editedMask
        let editedRange = textStorage.editedRange
        let changeInLength = textStorage.changeInLength
        let documentLength = textStorage.length

        // Gutter invalidation (perf C1).
        //
        // The gutter only renders line numbers, so its content only changes
        // when line *count* changes. Intra-line edits (typing on one line) do
        // not affect any line number and don't need a redraw.
        //
        // Heuristic for "line count changed":
        //   - Insertions: cheap — substring of `editedRange` contains "\n".
        //   - Deletions: we cannot read deleted content from `textStorage`,
        //     so any deletion conservatively invalidates. This is fine in
        //     practice — keystroke deletes are far rarer than inserts.
        //   - Replacements (`changeInLength == 0` with edited characters): also
        //     conservative — invalidate.
        let mightChangeLineCount: Bool = {
            guard editedMask.contains(.editedCharacters), editedRange.location != NSNotFound else {
                return false
            }
            if changeInLength <= 0 {
                return true
            }
            let fullString = textStorage.string
            let totalLength = fullString.utf16.count
            let safeStart = max(0, editedRange.location)
            let safeLength = min(editedRange.length, max(0, totalLength - safeStart))
            guard safeLength > 0 else { return false }
            let safeRange = NSRange(location: safeStart, length: safeLength)
            guard let editedSubstring = Range(safeRange, in: fullString) else { return false }
            return fullString[editedSubstring].contains("\n")
        }()
        if mightChangeLineCount {
            #if canImport(AppKit)
            gutterViewStorage?.needsDisplay = true
            #else
            gutterViewStorage?.setNeedsDisplay()
            #endif
        }

        // Defer all observer fan-out one runloop hop so it runs after the
        // outer `NSTextContentStorage.performEditingTransaction` closes.
        //
        // Why: inside that transaction, NSTextContentStorage is still
        // considered "in-edit"; any sync consumer that calls
        // `enumerateTextLayoutFragments`, `enumerateTextElements`, or
        // recursively opens a `beginEditing`/`endEditing` transaction
        // trips `NSTextContentStorageBreakOnEnumerateWhileEditing`.
        // Concrete tripwires:
        //   - `RangeBasedHighlightingController.textStorageDidApplyEdit`
        //     flows into `VisibleRangeProvider` which enumerates layout
        //     fragments via `TextKitBridge.visibleRange`.
        //   - `RangeAttributeApplier.textStorageDidApplyEdit` opens a
        //     nested `beginEditing`/`endEditing` on the same storage.
        //   - Accessibility clients enumerate text elements in response to
        //     `notifyAccessibilityTextDidChange`.
        // Apply syntax highlighting eagerly — `applySyntaxHighlighting(in:)`
        // itself debounces via `Task.sleep`, so it never re-enters the
        // current transaction.
        if editedMask.contains(.editedCharacters),
           configuration.display.isSyntaxHighlightingEnabled,
           editedRange.location != NSNotFound {
            applySyntaxHighlighting(in: editedRange)
        }

        guard editedRange.location != NSNotFound else { return }

        let oldLength = max(0, editedRange.length - changeInLength)
        let event = TextEditEvent(
            editedRange: NSRange(location: editedRange.location, length: oldLength),
            changeInLength: changeInLength,
            documentLength: documentLength,
            editedCharacters: editedMask.contains(.editedCharacters)
        )
        let shouldCheckCompletion = isCodeCompletionEnabled
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.textEditEventHub.publish(event)
            #if canImport(AppKit)
            self.publishEvent(.textDidChange(self.string))
            #else
            self.publishEvent(.textDidChange(self.text ?? ""))
            #endif
            self.notifyAccessibilityTextDidChange()
            if shouldCheckCompletion {
                self.checkForCompletionTrigger(at: editedRange)
            }
        }
    }

    // MARK: - Apply Highlighting

    internal func applySyntaxHighlighting() {
        highlightingController.applyFullDocument()
    }

    internal func applySyntaxHighlighting(in range: NSRange) {
        highlightingController.apply(in: range)
    }
}
