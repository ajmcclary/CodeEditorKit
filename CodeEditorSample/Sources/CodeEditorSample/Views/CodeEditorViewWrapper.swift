import CodeEditorPlugin
import SwiftUI

// MARK: - CodeEditorViewWrapper

struct CodeEditorViewWrapper: View {
    let configuration: EditorConfiguration
    @Binding var text: String
    let language: String
    let onTextViewReady: ((STTextView) -> Void)?

    init(
        configuration: EditorConfiguration,
        text: Binding<String>,
        language: String,
        onTextViewReady: ((STTextView) -> Void)? = nil
    ) {
        self.configuration = configuration
        self._text = text
        self.language = language
        self.onTextViewReady = onTextViewReady
    }

    var body: some View {
        UnifiedCodeEditorView(
            configuration: configuration,
            text: $text,
            language: language,
            onTextViewReady: onTextViewReady
        )
        .background(Color(configuration.theme.backgroundColor))
    }
}

// MARK: - UnifiedCodeEditorView

struct UnifiedCodeEditorView: NSViewRepresentable {
    let configuration: EditorConfiguration
    @Binding var text: String
    let language: String
    let onTextViewReady: ((STTextView) -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        // Create NSScrollView
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = !configuration.wrapLines
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        
        // Configure smooth scrolling
        if configuration.smoothScrolling {
            scrollView.scrollerStyle = .overlay
            scrollView.verticalScrollElasticity = .automatic
            scrollView.horizontalScrollElasticity = .automatic
        } else {
            scrollView.scrollerStyle = .legacy
            scrollView.verticalScrollElasticity = .none
            scrollView.horizontalScrollElasticity = .none
        }

        let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        // Set delegate
        textView.textDelegate = context.coordinator

        // Set the text content
        textView.text = text

        // Apply configuration
        applyConfiguration(to: textView)
        
        // Set up annotation manager if enabled
        if configuration.enableAnnotations {
            context.coordinator.annotationManager = AnnotationManager(textView: textView)
            context.coordinator.annotationManager?.scanForAnnotations()
        }

        // Configure text view for scroll view based on word wrap setting
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = !configuration.wrapLines
        textView.textContainer?.widthTracksTextView = configuration.wrapLines
        textView.textContainer?.heightTracksTextView = false
        
        // Set container width for non-wrapping mode
        if !configuration.wrapLines {
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }

        // Set the text view as the document view
        scrollView.documentView = textView

        // Ensure the text view is properly laid out
        textView.invalidateIntrinsicContentSize()
        textView.needsLayout = true
        textView.needsDisplay = true

        // Notify that text view is ready if callback provided
        onTextViewReady?(textView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? STTextView else { return }
        
        // Update text if changed
        if textView.text != text {
            textView.text = text
        }

        // Update configuration
        applyConfiguration(to: textView)
        
        // Update scroll view settings based on word wrap
        scrollView.hasHorizontalScroller = !configuration.wrapLines
        
        // Update smooth scrolling settings
        if configuration.smoothScrolling {
            scrollView.scrollerStyle = .overlay
            scrollView.verticalScrollElasticity = .automatic
            scrollView.horizontalScrollElasticity = .automatic
        } else {
            scrollView.scrollerStyle = .legacy
            scrollView.verticalScrollElasticity = .none
            scrollView.horizontalScrollElasticity = .none
        }
        
        // Update text container settings for word wrap
        textView.isHorizontallyResizable = !configuration.wrapLines
        textView.textContainer?.widthTracksTextView = configuration.wrapLines
        
        // Set container width for non-wrapping mode
        if !configuration.wrapLines {
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        } else {
            // Reset container size for wrapping mode
            if let scrollViewWidth = scrollView.enclosingScrollView?.contentSize.width {
                textView.textContainer?.containerSize = NSSize(
                    width: scrollViewWidth,
                    height: CGFloat.greatestFiniteMagnitude
                )
            }
        }
        
        // Update annotations
        if configuration.enableAnnotations {
            if context.coordinator.annotationManager == nil {
                context.coordinator.annotationManager = AnnotationManager(textView: textView)
            }
            context.coordinator.annotationManager?.scanForAnnotations()
        } else {
            // Clear annotations if disabled
            context.coordinator.annotationManager?.clearAnnotations()
            context.coordinator.annotationManager = nil
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func applyConfiguration(to textView: STTextView) {
        // Basic settings
        textView.isEditable = configuration.isEditable
        textView.isSelectable = true
        textView.allowsUndo = true

        // Line numbers
        textView.showsLineNumbers = configuration.showLineNumbers

        // Font
        textView.font = NSFont.monospacedSystemFont(
            ofSize: configuration.fontSize,
            weight: .regular
        )

        // Colors
        textView.textColor = configuration.theme.textColor
        textView.backgroundColor = configuration.theme.backgroundColor
        textView.selectedLineHighlightColor = configuration.theme.selectedLineColor
        textView.insertionPointColor = configuration.insertionPointColor
        
        // Selection attributes based on theme
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.selectedTextBackgroundColor,
            .foregroundColor: NSColor.selectedTextColor
        ]

        // Line highlighting
        textView.highlightSelectedLine = configuration.highlightSelectedLine

        // Invisible characters
        textView.showsInvisibleCharacters = configuration.showInvisibleCharacters

        // Text container settings
        textView.textContainerInset = configuration.textContainerInset
        textView.textContainer?.lineFragmentPadding = configuration.lineFragmentPadding

        // Make sure the text view is properly sized
        textView.isVerticallyResizable = true

        // Tab settings
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.tabStops = []
        paragraphStyle.defaultTabInterval = CGFloat(configuration.tabWidth) * 7.0
        paragraphStyle.lineSpacing = configuration.lineSpacing
        textView.defaultParagraphStyle = paragraphStyle
        
        // Text processing settings
        textView.isContinuousSpellCheckingEnabled = configuration.isContinuousSpellCheckingEnabled
        textView.isGrammarCheckingEnabled = configuration.isGrammarCheckingEnabled
        textView.isAutomaticQuoteSubstitutionEnabled = configuration.isAutomaticQuoteSubstitutionEnabled
        textView.isAutomaticDashSubstitutionEnabled = configuration.isAutomaticDashSubstitutionEnabled
        textView.isAutomaticTextReplacementEnabled = configuration.isAutomaticTextReplacementEnabled
        textView.isAutomaticSpellingCorrectionEnabled = configuration.isAutomaticSpellingCorrectionEnabled
        textView.isAutomaticTextCompletionEnabled = configuration.isAutomaticTextCompletionEnabled
        textView.isIncrementalSearchingEnabled = configuration.isIncrementalSearchingEnabled
        
        // Advanced text settings
        textView.allowsDocumentBackgroundColorChange = configuration.allowsDocumentBackgroundColorChange
        textView.allowsImageEditing = configuration.allowsImageEditing
        textView.allowsCharacterPickerTouchBarItem = configuration.allowsCharacterPickerTouchBarItem
        textView.isRichText = configuration.isRichText
        textView.importsGraphics = configuration.importsGraphics
        textView.usesInspectorBar = configuration.usesInspectorBar
        textView.usesFindBar = configuration.usesFindBar
        // Note: allowsNonContiguousLayout is not available on STTextView
        textView.displaysLinkToolTips = configuration.displaysLinkToolTips
        
        // Performance settings
        if configuration.useHardwareAcceleration {
            textView.wantsLayer = true
            textView.layer?.drawsAsynchronously = true
        }

        // Set language for syntax highlighting using file extension
        textView.setLanguage(fileExtension: language)
    }

    // MARK: - Coordinator

    @MainActor
    class Coordinator: NSObject, @preconcurrency STTextViewDelegate {
        var parent: UnifiedCodeEditorView
        var annotationManager: AnnotationManager?

        init(_ parent: UnifiedCodeEditorView) {
            self.parent = parent
            super.init()
        }

        // MARK: - STTextViewDelegate

        func undoManager(for _: STTextView) -> UndoManager? {
            nil
        }

        func textViewWillChangeText(_: Notification) {
            // Default implementation
        }

        func textViewDidChangeText(_ notification: Notification) {
            if let textView = notification.object as? STTextView {
                parent.text = textView.text ?? ""
                
                // Re-scan for annotations if enabled
                if parent.configuration.enableAnnotations {
                    annotationManager?.scanForAnnotations()
                }
            }
        }

        func textViewDidChangeSelection(_: Notification) {
            // Handle selection changes if needed
        }

        func textView(
            _ textView: STTextView,
            shouldChangeTextIn affectedCharRange: NSTextRange,
            replacementString: String?
        ) -> Bool {
            guard let replacementString = replacementString else { return true }
            
            // Note: Tab handling and auto-indent would require deeper integration with STTextView's
            // text system. For now, these features are documented but not implemented.
            
            return true
        }

        func textView(
            _ textView: STTextView,
            willChangeTextIn affectedCharRange: NSTextRange,
            replacementString: String
        ) {
            // Default implementation
        }

        func textView(
            _: STTextView,
            didChangeTextIn _: NSTextRange,
            replacementString _: String
        ) {
            // Default implementation
        }

        func textView(_: STTextView, clickedOnLink _: Any, at _: any NSTextLocation) -> Bool {
            false
        }

        func textView(_: STTextView, insertCompletionItem _: any STCompletionItem) {
            // Default implementation
        }

        func textViewCompletionViewController(_: STTextView) -> any STCompletionViewControllerProtocol {
            fatalError("Completion view controller not implemented")
        }

        func textViewInsertionPointView(
            _: STTextView,
            frame _: CGRect
        ) -> (any STInsertionPointIndicatorProtocol)? {
            nil
        }

        func textView(
            _: STTextView,
            clickedOnAttachment _: NSTextAttachment,
            at _: any NSTextLocation
        ) -> Bool {
            false
        }

        func textView(
            _: STTextView,
            shouldAllowInteractionWith _: NSTextAttachment,
            at _: any NSTextLocation
        ) -> Bool {
            true
        }
    }
}
