import CodeEditorLayout
import CodeEditorPlatform
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Configuration & Line Highlighting

extension CodeEditorView {
    // MARK: - Configuration Application

    internal func applyConfiguration() {
        CodeEditorRenderingDiagnostics.logConfigurationDispatch(
            "textView.applyConfiguration.begin",
            textView: self
        )

        // Apply display settings
        #if canImport(AppKit)
        // On macOS, line numbers are handled by NSRulerView in the container
        // Always ensure no GutterView exists on the text view itself
        updateGutterVisibility()
        #else
        // On iOS, gutter is handled by the container view
        // But when used standalone, the text view should manage its own gutter
        updateGutterVisibility()
        #endif

        if configuration.display.isSelectedLineHighlighted {
            updateSelectedLineHighlight()
        } else {
            removeLineHighlight()
        }

        if configuration.display.isSyntaxHighlightingEnabled {
            applySyntaxHighlighting()
        } else {
            removeSyntaxHighlighting()
        }

        updateLayoutManagerSettings()

        // Apply font settings
        font = PlatformFonts.monospacedSystemFont(ofSize: configuration.display.fontSize, weight: .regular)
        // Base text colour: defer to the applied theme's editor.foreground
        // when present so config changes don't reset the theme back to the
        // system label colour (which goes invisible on dark themes when the
        // window's effective appearance doesn't switch with the theme).
        if let themeForeground = appliedTheme?.style.editor.foreground {
            textColor = PlatformColor(tokens: themeForeground)
        } else {
            textColor = PlatformColors.label
        }

        // Apply layout settings
        #if canImport(AppKit)
        updateTextContainerSize()
        #endif

        // Apply paragraph style for tab width and line spacing
        applyParagraphStyle()

        // Apply word wrap settings (especially important on iOS when font size changes)
        ContainerViewHelper.configureTextViewScrolling(self, wrapLines: configuration.layout.wrapLines)
        #if canImport(AppKit)
        // The line above makes a wrapping container track the full width again.
        applyWrapWidthFraction()
        #endif

        // Update text container size for word wrap changes
        #if canImport(UIKit)
        updateTextContainerSize()
        #endif

        // Ensure text colors are visible on iOS

        // Apply behavior settings
        isEditable = configuration.behavior.isEditable
        isSelectable = configuration.behavior.isSelectable

        // Apply text input behavior settings on macOS
        #if canImport(AppKit)
        isAutomaticTextCompletionEnabled = configuration.behavior.isAutomaticTextCompletionEnabled
        isAutomaticQuoteSubstitutionEnabled = configuration.behavior.isAutomaticQuoteSubstitutionEnabled
        isAutomaticDashSubstitutionEnabled = configuration.behavior.isAutomaticDashSubstitutionEnabled
        isAutomaticTextReplacementEnabled = configuration.behavior.isAutomaticTextReplacementEnabled
        isAutomaticSpellingCorrectionEnabled = configuration.behavior.isAutomaticSpellingCorrectionEnabled
        isGrammarCheckingEnabled = configuration.behavior.isGrammarCheckingEnabled
        isContinuousSpellCheckingEnabled = configuration.behavior.isContinuousSpellCheckingEnabled
        #endif
        applyLinkDetection()
        applyInlinePredictions()

        // The configured trigger characters, or the language's own.
        updateCompletionTriggerCharacters()

        // Update code folding configuration
        updateCodeFoldingConfiguration()
        updateRangeBasedHighlightingConfiguration()

        // Force layout update
        #if canImport(AppKit)
        needsLayout = true
        #else
        setNeedsLayout()
        #endif

        // Notify container view to update gutter width if needed
        containerView?.applyConfiguration()
        CodeEditorRenderingDiagnostics.logConfigurationDispatch(
            "textView.applyConfiguration.end",
            textView: self
        )
    }

    // MARK: - Line Highlighting

    @objc
    internal func handleTextViewDidChangeSelection(_: Notification) {
        // Forward to the host's delegate synchronously — Apple's NSTextView
        // contract is that `textViewDidChangeSelection` runs in the same
        // turn as the selection change, and callers that override it expect
        // that timing.
        delegateProxy.textViewDidChangeSelection(self)

        // Defer everything that may enumerate the TextKit2 layout or text
        // content storage. AppKit re-emits selection change notifications
        // from inside `NSTextStorage.endEditing` whenever a replace moves
        // the caret (see backtrace in
        // CodeEditorView+SyntaxHighlightingExtensions.swift), so any sync
        // call into `enumerateTextLayoutFragments` here trips
        // `NSTextContentStorageBreakOnEnumerateWhileEditing`.
        // - updateSelectedLineHighlight → calculateLineRect → enumerateTextLayoutFragments
        // - NotificationCenter.post + eventPublisher.publishSync may invoke
        //   observers that also enumerate.
        let currentSelection = selectedRange
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.updateSelectedLineHighlight()
            self.updateCompletionAfterSelectionChange()
            self.publishEvent(.textSelectionDidChange(currentSelection))
        }
    }

    internal func updateSelectedLineHighlight() {
        guard isSelectedLineHighlightEnabled else {
            removeLineHighlight()
            return
        }

        createLineHighlightIfNeeded()
        updateLineHighlightFrame()
    }

    private func createLineHighlightIfNeeded() {
        guard lineHighlightView == nil else {
            return
        }

        let highlight = LineHighlightView()
        highlight.highlightColor = configuration.display.selectedLineHighlightColor

        // Add as background overlay
        #if canImport(AppKit)
        addSubview(highlight, positioned: .below, relativeTo: nil)
        #else
        addSubview(highlight)
        sendSubviewToBack(highlight)
        #endif
        lineHighlightView = highlight
    }

    private func removeLineHighlight() {
        lineHighlightView?.removeFromSuperview()
        lineHighlightView = nil
    }

    internal func updateLineHighlightFrame() {
        guard let highlightView = lineHighlightView else {
            return
        }

        let selectedRange = selectedRange
        guard selectedRange.location != NSNotFound else {
            return
        }

        // Get the line range for the selection
        #if canImport(AppKit)
        // One NSString line lookup instead of copying the document twice.
        // swiftlint:disable:next legacy_objc_type
        let text = string as NSString
        guard NSMaxRange(selectedRange) <= text.length else { return }
        let lineRange = text.lineRange(for: selectedRange)
        #else
        guard let text = self.text,
              let range = Range(selectedRange, in: text) else { return }
        let stringLineRange = text.lineRange(for: range)
        let lineRange = NSRange(stringLineRange, in: text)
        #endif

        // Get the rect for the line using TextKit2-compatible approach
        guard let lineRect = calculateLineRect(for: lineRange) else {
            return
        }

        // Adjust frame. `calculateLineRect` answers in the text container's
        // coordinates; the highlight is a subview, so it needs the view's.
        var frame = lineRect
        frame.origin.x = 0
        frame.size.width = bounds.width
        #if canImport(AppKit)
        frame.origin.y += textContainerOrigin.y
        #endif

        highlightView.frame = frame
        if let lineHighlight = highlightView as? LineHighlightView {
            lineHighlight.highlightColor = configuration.display.selectedLineHighlightColor
        }
    }

    // MARK: - Text Input Behavior

    /// Applies `behavior.isAutomaticLinkDetectionEnabled`. Turning it on
    /// also checks the text already in the document; turning it off removes
    /// the links detection added, which the text system would otherwise
    /// keep drawing.
    private func applyLinkDetection() {
        let isEnabled = configuration.behavior.isAutomaticLinkDetectionEnabled
        #if canImport(AppKit)
        guard isAutomaticLinkDetectionEnabled != isEnabled else { return }
        isAutomaticLinkDetectionEnabled = isEnabled
        if isEnabled {
            checkTextInDocument(nil)
        } else if let storage = textContentStorage?.textStorage, storage.length > 0 {
            storage.removeAttribute(.link, range: NSRange(location: 0, length: storage.length))
        }
        #else
        // UIKit only detects links in text that is not editable.
        dataDetectorTypes = isEnabled ? .link : []
        #endif
    }

    /// Applies `behavior.showInlineCompletionSuggestions` to the system's
    /// inline predictions: off never shows them in the editor, on follows
    /// the user's system-wide setting.
    private func applyInlinePredictions() {
        inlinePredictionType = configuration.behavior.showInlineCompletionSuggestions ? .default : .no
    }

    // MARK: - Layout Manager Settings

    /// Applies `display.areInvisibleCharactersVisible`.
    ///
    /// `NSLayoutManager.showsInvisibleCharacters` is TK1-only, and reading
    /// the legacy `layoutManager` on a TK2-initialized NSTextView triggers
    /// Apple's TK1 compatibility shim and clears `textLayoutManager`. Under
    /// TK2 the marks are drawn by `TextLayoutFragment`, which the layout
    /// manager only vends while this view is its delegate — so the delegate
    /// is installed for exactly as long as the setting is on, and editors
    /// that leave it off keep the system's own fragments.
    private func updateLayoutManagerSettings() {
        #if canImport(AppKit)
        guard let textLayoutManager else { return }
        let isEnabled = configuration.display.areInvisibleCharactersVisible
        let isInstalled = textLayoutManager.delegate === self
        guard isEnabled != isInstalled else { return }
        textLayoutManager.delegate = isEnabled ? self : nil
        // Existing fragments were made by the previous vendor.
        textLayoutManager.invalidateLayout(for: textLayoutManager.documentRange)
        needsDisplay = true
        #endif
    }

    // MARK: - Syntax Highlighting Toggle

    internal func removeSyntaxHighlighting() {
        // Cancel any in-progress highlighting first
        highlightingController.cancelActiveWork()

        // Syntax highlighting now lives in NSTextLayoutManager rendering
        // attributes (see RangeAttributeApplier + AsyncSyntaxHighlighter).
        // Remove token foregrounds, then seed the theme's base foreground
        // back into the rendering surface. TK2 does not reliably fall back
        // to `NSTextView.textColor` or storage foreground for glyph drawing.
        let textLength = textKitBridge.documentLength
        guard textLength > 0 else { return }
        let fullRange = NSRange(location: 0, length: textLength)
        CodeEditorRenderingDiagnostics.log(
            "configuration.removeSyntaxHighlighting",
            textView: self,
            theme: appliedTheme,
            note: "range={\(fullRange.location),\(fullRange.length)}"
        )
        textKitBridge.removeAttributes([.foregroundColor], range: fullRange)
        stampThemeForeground(overwritingExistingForeground: false)
    }

    // MARK: - Code Folding Configuration

    /// Update code folding configuration from EditorConfiguration
    internal func updateCodeFoldingConfiguration() {
        codeFoldingEngine.configuration = configuration.createCodeFoldingConfiguration()

        // Update folding regions if folding is enabled
        if configuration.display.isCodeFoldingEnabled {
            // Update the folding engine with current language
            codeFoldingEngine.attach(to: self)
        }
    }
}
