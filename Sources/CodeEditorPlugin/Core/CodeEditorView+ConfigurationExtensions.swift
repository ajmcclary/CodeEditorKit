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
            let selectionNotification = Notification(
                name: Self.codeEditorViewDidChangeSelectionNotification,
                object: self
            )
            NotificationCenter.default.post(selectionNotification)
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
        guard let range = Range(selectedRange, in: string) else { return }
        let stringLineRange = string.lineRange(for: range)
        let lineRange = NSRange(stringLineRange, in: string)
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

        // Adjust frame
        var frame = lineRect
        frame.origin.x = 0
        frame.size.width = bounds.width
        // Don't add textContainerInset here - calculateLineRect already accounts for it

        highlightView.frame = frame
        if let lineHighlight = highlightView as? LineHighlightView {
            lineHighlight.highlightColor = configuration.display.selectedLineHighlightColor
        }
    }

    // MARK: - Layout Manager Settings

    private func updateLayoutManagerSettings() {
        // `NSLayoutManager.showsInvisibleCharacters` is TK1-only; reading the
        // legacy `layoutManager` property on a TK2-initialized NSTextView
        // triggers Apple's TK1 compatibility shim and clears
        // `textLayoutManager`. Showing invisible characters under TK2 requires
        // a separate rendering-attribute-based implementation and is currently
        // not wired up. Tracked as a known gap; the property setter is a
        // deliberate no-op so we don't re-arm the coercion.
    }

    // MARK: - Syntax Highlighting Toggle

    internal func removeSyntaxHighlighting() {
        // Cancel any in-progress highlighting first
        asyncHighlighter.cancelAllHighlighting()

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
