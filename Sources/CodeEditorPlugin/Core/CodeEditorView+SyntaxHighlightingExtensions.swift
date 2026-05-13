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
        guard let textStorage = notification.object as? NSTextStorage,
              textStorage === self.textStorage
        else {
            return
        }

        // Publish a canonical edit event for all observers.
        let editedMask = textStorage.editedMask
        let editedRange = textStorage.editedRange
        if editedRange.location != NSNotFound {
            let changeInLength = textStorage.changeInLength
            let oldLength = max(0, editedRange.length - changeInLength)
            let event = TextEditEvent(
                editedRange: NSRange(location: editedRange.location, length: oldLength),
                changeInLength: changeInLength,
                documentLength: textStorage.length,
                editedCharacters: editedMask.contains(.editedCharacters)
            )
            textEditEventHub.publish(event)
        }

        // Note: Line geometry store is kept in sync by LineGeometryEditHandler
        // via TextEditEventHub — no manual invalidation needed.

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
            let changeInLength = textStorage.changeInLength
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

        // Apply syntax highlighting to the edited range if enabled.
        // Only trigger for character edits — attribute-only edits are
        // produced by the range attribute applier and must not re-enter
        // the highlighting pipeline (prevents loops and double-apply).
        if editedMask.contains(.editedCharacters),
           configuration.display.isSyntaxHighlightingEnabled {
            let editedRange = textStorage.editedRange
            if editedRange.location != NSNotFound {
                applySyntaxHighlighting(in: editedRange)
            }
        }

        // On iOS, ensure text remains visible after edits

        // Publish text changed event
        if editedRange.location != NSNotFound {
            #if canImport(AppKit)
            eventPublisher.publishSync(.textDidChange(string))
            #else
            eventPublisher.publishSync(.textDidChange(text ?? ""))
            #endif

            // Update accessibility for text changes
            notifyAccessibilityTextDidChange()

            // Check for completion triggering
            if isCodeCompletionEnabled {
                checkForCompletionTrigger(at: editedRange)
            }

            // LSP document context can be updated here when integrated
            // updateLSPDocumentContext()
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
        #if canImport(AppKit)
        let textLength = textStorage?.length ?? 0
        #else
        let textLength = textStorage.length
        #endif

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
        #if canImport(AppKit)
        let textLength = textStorage?.length ?? 0
        #else
        let textLength = textStorage.length
        #endif

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
