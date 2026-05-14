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
            self.eventPublisher.publishSync(.textDidChange(self.string))
            #else
            self.eventPublisher.publishSync(.textDidChange(self.text ?? ""))
            #endif
            self.notifyAccessibilityTextDidChange()
            if shouldCheckCompletion {
                self.checkForCompletionTrigger(at: editedRange)
            }
        }
    }

    // MARK: - Apply Highlighting

    /// `true` when the range-store pipeline is the primary text-styling
    /// path and the legacy highlighter should yield to it.
    private var isRangeStorePrimary: Bool {
        configuration.display.useRangeStoreHighlighting
            && rangeBasedHighlightingController != nil
    }

    internal func applySyntaxHighlighting() {
        updateRangeBasedHighlightingConfiguration()
        let syntaxService = featureDependencies.syntaxHighlightingService
        let textLength = textKitBridge.documentLength

        // Update adaptive performance mode based on file size
        adaptivePerformanceMode.updateMode(for: textLength, language: language)

        // Apply adaptive performance configuration, but preserve explicit user settings
        var updatedConfig = configuration

        // Store user preferences before adaptive mode overwrites them
        let userLineNumbersSetting = configuration.display.isLineNumbersEnabled
        let userCodeFoldingSetting = configuration.display.isCodeFoldingEnabled
        let userSyntaxHighlightingSetting = configuration.display.isSyntaxHighlightingEnabled

        adaptivePerformanceMode.applyConfiguration(to: &updatedConfig)

        // Restore user-specified settings - adaptive mode should not override explicit user choices
        // Only apply adaptive performance to performance-related settings, not UI preferences
        updatedConfig.display.isLineNumbersEnabled = userLineNumbersSetting
        updatedConfig.display.isCodeFoldingEnabled = userCodeFoldingSetting
        updatedConfig.display.isSyntaxHighlightingEnabled = userSyntaxHighlightingSetting

        // Only update configuration if it actually changed to prevent feedback loops
        if configuration != updatedConfig {
            configuration = updatedConfig
        }

        guard syntaxService.shouldApplySyntaxHighlighting(
            isEnabled: isSyntaxHighlightingEnabled,
            textLength: textLength,
            maxLength: configuration.performance.maxSyntaxHighlightingLength
        ) else {
            syntaxService.cancelHighlighting(asyncHighlighter: asyncHighlighter)
            return
        }

        // When the range-store pipeline is primary, the attribute applier
        // handles text styling — skip the legacy full-document schedule.
        // The range-based configuration was already updated above.
        if isRangeStorePrimary { return }

        syntaxService.scheduleHighlighting(
            asyncHighlighter: asyncHighlighter,
            textView: self,
            language: language,
            visibleRange: nil
        )
    }

    internal func applySyntaxHighlighting(in range: NSRange) {
        // When the range-store pipeline is primary, character-edit
        // highlighting is handled by the range attribute applier.
        // Skip the legacy scheduling entirely.
        if isRangeStorePrimary { return }

        let syntaxService = featureDependencies.syntaxHighlightingService
        let textLength = textKitBridge.documentLength

        guard syntaxService.isValidHighlightingRange(range, textLength: textLength) else {
            return
        }

        guard syntaxService.shouldApplySyntaxHighlighting(
            isEnabled: isSyntaxHighlightingEnabled,
            textLength: textLength,
            maxLength: configuration.performance.maxSyntaxHighlightingLength
        ) else {
            return
        }

        syntaxService.scheduleHighlighting(
            asyncHighlighter: asyncHighlighter,
            textView: self,
            language: language,
            visibleRange: range
        )
    }
}
