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

        // Invalidate line index cache when text changes
        lineIndexCache.invalidate()

        // Pre-warm cache for visible content if this is a significant text change
        // Defer the pre-warming to avoid conflicts with text storage editing
        if textStorage.editedMask.contains(.editedCharacters) {
            Task { @MainActor [weak self] in
                guard let self else { return }
                #if canImport(AppKit)
                // For macOS, use visible rect to determine character range
                if let layoutManager = self.layoutManager,
                   let textContainer = self.textContainer,
                   let textStorage = self.textStorage {
                    let glyphRange = layoutManager.glyphRange(forBoundingRect: self.visibleRect, in: textContainer)
                    let visibleNSRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
                    self.lineIndexCache.preWarmCache(for: textStorage.string, visibleRange: visibleNSRange)
                }
                #else
                let visibleNSRange = NSRange(location: 0, length: min(1_000, self.textStorage.length))
                self.lineIndexCache.preWarmCache(for: self.textStorage.string, visibleRange: visibleNSRange)
                #endif
            }
        }

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

        // Apply syntax highlighting to the edited range if enabled
        if configuration.display.isSyntaxHighlightingEnabled {
            let editedRange = textStorage.editedRange
            if editedRange.location != NSNotFound {
                applySyntaxHighlighting(in: editedRange)
            }
        }

        // On Mac Catalyst, ensure text remains visible after edits

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

    internal func applySyntaxHighlighting() {
        updateRangeBasedHighlightingConfiguration()
        let syntaxService = businessLogicServices.syntaxHighlightingService
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

        syntaxService.scheduleHighlighting(
            asyncHighlighter: asyncHighlighter,
            textView: self,
            language: language,
            visibleRange: nil
        )
    }

    internal func applySyntaxHighlighting(in range: NSRange) {
        let syntaxService = businessLogicServices.syntaxHighlightingService
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
